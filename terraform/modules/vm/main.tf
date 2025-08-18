/*
* Generate a ~/.ssh/k8s_cluster_config file in the user's home directory with an alias and a specified public key
* for passwordless SSH using the alias (e.g., ssh vm200).
*/
resource "local_file" "ssh_config" {
  content = templatefile("${path.root}/templates/ssh_config.tftpl", {
    nodes                = var.all_nodes,
    ssh_user             = var.vm_username,
    ssh_private_key_path = var.ssh_private_key_path
  })
  filename        = pathexpand("~/.ssh/k8s_cluster_config")
  file_permission = "0600"
}

/*
* NOTE: Call functions in `utils_ssh.sh` via local-exec to manage the ~/.ssh/config file. 
* This avoids deletion during `terraform destroy()` in `scripts/terraform.sh`.
*/
resource "null_resource" "ssh_config_include" {
  depends_on = [local_file.ssh_config]

  provisioner "local-exec" {
    command     = ". ${path.root}/../scripts/utils_ssh.sh && integrate_ssh_config"
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = ". ${path.root}/../scripts/utils_ssh.sh && deintegrate_ssh_config"
    interpreter = ["/bin/bash", "-c"]
  }
}

/*
* NOTE: Using local-exec and remote-exec to configure VMs as a workaround 
* due to the lack of a stable VMware Workstation provider. 
* This is a known technical debt.
*/
resource "null_resource" "configure_nodes" {
  depends_on = [local_file.ssh_config, null_resource.ssh_config_include]
  for_each   = { for node in var.all_nodes : node.key => node }

  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${var.vms_dir}/${each.key}
      mkdir -p ${var.vms_dir}/${each.key}
      vmrun -T ws clone ${var.vmx_image_path} ${each.value.path} full -cloneName=${each.key}
      sed -i '/^numvcpus/d' ${each.value.path}
      sed -i '/^memsize/d' ${each.value.path}
      echo 'numvcpus = "${each.value.vcpu}"' >> ${each.value.path}
      echo 'memsize = "${each.value.ram}"' >> ${each.value.path}
      sed -i '/^ethernet1\./d' ${each.value.path}
      echo 'ethernet1.present = "TRUE"' >> ${each.value.path}
      echo 'ethernet1.connectionType = "hostonly"' >> ${each.value.path}
      echo 'ethernet1.virtualDev = "e1000"' >> ${each.value.path}
      vmrun -T ws start ${each.value.path} nogui
      sleep 10
      vmrun -T ws getGuestIPAddress ${each.value.path} -wait > ${var.vms_dir}/${each.key}/nat_ip.txt || true
    EOT
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.vm_username
      private_key = file(var.ssh_private_key_path)
      host        = try(trimspace(file("${var.vms_dir}/${each.key}/nat_ip.txt")), "failed")
      port        = 22
      timeout     = "3m"
      agent       = false
    }

    inline = [
      "sleep 5",
      "sudo cloud-init clean --logs || true",
      "sudo systemctl disable cloud-init || true",
      "sudo systemctl stop cloud-init || true",
      "sudo touch /etc/cloud/cloud-init.disabled || true",
      "sudo rm -f /etc/machine-id",                      # Reset machine-id to avoid DUID conflicts
      "sudo systemd-machine-id-setup",                   # Generate new machine-id
      "sudo systemctl stop systemd-networkd || true",    # Stop networkd to prevent DHCP interference
      "sudo systemctl disable systemd-networkd || true", # Disable networkd
      "sudo modprobe e1000 || true",
      "sudo udevadm trigger || true",
      "HOSTONLY_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v -e '^lo$' -e '^ens33$' | head -n 1)",
      "if [ -z \"$HOSTONLY_IFACE\" ]; then echo 'Error: Host-only network interface not found'; ip -o link show; exit 1; fi",
      "echo 'network:\n  version: 2\n  ethernets:\n    ens33:\n      dhcp4: false\n      addresses: [172.16.86.${split(".", each.value.ip)[3]}/24]\n      nameservers:\n        addresses: [8.8.8.8, 8.8.4.4]\n      dhcp6: false\n    '$HOSTONLY_IFACE':\n      dhcp4: false\n      addresses: [${each.value.ip}/24]' | sudo tee /etc/netplan/00-hostonly.yaml",
      "sudo chmod 600 /etc/netplan/00-hostonly.yaml",
      "sudo netplan apply || { echo 'Error: netplan apply failed'; cat /etc/netplan/00-hostonly.yaml; exit 1; }",
      "sleep 5",
      "sudo ip link set $HOSTONLY_IFACE up", # Explicitly bring up host-only interface
      "sudo hostnamectl set-hostname ${each.key}",
      "chmod 755 /home/${var.vm_username}",
      "sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config",
      "sudo sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config",
      "sudo systemctl restart sshd"
    ]
    on_failure = continue
  }
}

/*
* This makes sure this resource runs only after the "for_each" loop
* in "configure_nodes" has completed for all nodes.
*/
resource "null_resource" "prepare_ssh_access" {
  depends_on = [null_resource.configure_nodes]

  provisioner "local-exec" {
    command     = <<-EOT
      set -e
      echo ">>> Verifying VM liveness and preparing SSH access..."
      . ${path.root}/../scripts/utils_ssh.sh
      bootstrap_ssh_known_hosts ${join(" ", [for node in var.all_nodes : node.ip])}
      echo ">>> Liveness check passed. SSH access is ready."
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
