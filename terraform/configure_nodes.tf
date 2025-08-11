/*
NOTE: Using `local-exec` and `remote-exec` to configure VMs as a workaround 
due to the lack of a stable VMware Workstation provider. 
This is a known technical debt.
*/
resource "null_resource" "configure_nodes" {
  depends_on = [local_file.ssh_config]
  for_each = { for node in local.all_nodes : node.key => node }

  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${local.vms_dir}/${each.key}
      mkdir -p ${local.vms_dir}/${each.key}
      vmrun -T ws clone ${local.vmx_image_path} ${each.value.path} full -cloneName=${each.key}
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
      vmrun -T ws getGuestIPAddress ${each.value.path} -wait > ${local.vms_dir}/${each.key}/nat_ip.txt || true
    EOT
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = var.vm_username
      password = var.vm_password
      host     = try(trimspace(file("${local.vms_dir}/${each.key}/nat_ip.txt")), "failed")
      port     = 22
      timeout  = "10m"
      agent    = false
    }

    inline = [
      # Wait for SSH and network to stabilize
      "sleep 5",
      # Clear cloud-init state to prevent reset
      "sudo cloud-init clean --logs || true",
      "sudo systemctl disable cloud-init || true",
      "sudo systemctl stop cloud-init || true",
      "sudo touch /etc/cloud/cloud-init.disabled || true",
      # Reload network drivers and bring up host-only interface
      "sudo modprobe e1000 || true",
      "sudo udevadm trigger || true",
      # Detect the host-only network interface
      # The script detects a HOSTONLY_IFACE but then proceeds to hardcode `ens32` in the Netplan configuration, and it assumes the NAT interface is ens33. 
      # This could fail if the interface names are different on the guest OS. The detected interface name should be used in the Netplan configuration to ensure robustness.
      "HOSTONLY_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v -e '^lo$' -e '^ens33$' | head -n 1)",
      "if [ -z \"$HOSTONLY_IFACE\" ]; then echo 'Error: Host-only network interface not found'; ip -o link show; exit 1; fi",
      # Configure Netplan with NAT handling external traffic
      "echo 'network:\n  version: 2\n  ethernets:\n    ens33:\n      dhcp4: true\n      dhcp6: false\n    '$HOSTONLY_IFACE':\n      dhcp4: false\n      addresses: [${each.value.ip}/24]' | sudo tee /etc/netplan/00-hostonly.yaml",
      "sudo chmod 600 /etc/netplan/00-hostonly.yaml",
      # Apply Netplan configuration with error checking and delay
      "if ! sudo netplan apply; then echo 'Error: netplan apply failed'; cat /etc/netplan/00-hostonly.yaml; exit 1; fi",
      "sleep 5",
      # Set hostname
      "sudo hostnamectl set-hostname ${each.key}",
      # Configure SSH public key and service
      "mkdir -p ~/.ssh",
      "chmod 700 ~/.ssh",
      "echo '${file("~/.ssh/id_ed25519_k8s-cluster.pub")}' > ~/.ssh/authorized_keys",
      "chmod 600 ~/.ssh/authorized_keys",
      # Ensure home directory permissions
      "chmod 755 /home/${var.vm_username}",
      # Configure sshd
      "sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config",
      "sudo sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config",
      # Verify SSH public key
      "sudo systemctl restart sshd"
    ]

    on_failure = continue
  }

  provisioner "local-exec" {
    command = <<EOT
      vmrun -T ws stop ${each.value.path} hard || true
    EOT
  }
}