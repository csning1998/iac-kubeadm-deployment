terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

locals {
  vms_dir = "${path.root}/vms"
  master_ip_list = var.master_ip_list
  worker_ip_list = var.worker_ip_list
  vmx_image_path = abspath("${path.root}/../packer/output/ubuntu-server-vmware/ubuntu-server-24-template-vmware.vmx")

  master_config = [
    for idx, ip in local.master_ip_list : {
      key       = "k8s-master-${format("%02d", idx)}"
      ip        = ip
      vcpu      = var.master_vcpu
      ram       = var.master_ram
      path      = "${local.vms_dir}/k8s-master-${format("%02d", idx)}/k8s-master-${format("%02d", idx)}.vmx"
    }
  ]

  workers_config = [
    for idx, ip in local.worker_ip_list : {
      key       = "k8s-worker-${format("%02d", idx)}"
      ip        = ip
      vcpu      = var.worker_vcpu
      ram       = var.worker_ram
      path      = "${local.vms_dir}/k8s-worker-${format("%02d", idx)}/k8s-worker-${format("%02d", idx)}.vmx"
    }
  ]

  all_nodes = concat(local.master_config, local.workers_config)
}

resource "null_resource" "generate_ssh_config" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ~/.ssh
      if [ ! -f ~/.ssh/id_ed25519_k8s-cluster ]; then
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_k8s-cluster -N "" -C "k8s-cluster-key"
      fi
      echo "# SSH configuration for Kubernetes cluster" > ~/.ssh/config
      chmod 600 ~/.ssh/config
      ${join("\n", [
        for node in local.all_nodes :
        "echo 'Host vm${split(".", node.ip)[3]}\n  HostName ${node.ip}\n  User ${var.vm_username}\n  IdentityFile ~/.ssh/id_ed25519_k8s-cluster' >> ~/.ssh/config"
      ])}
    EOT
  }
}

resource "null_resource" "configure_nodes" {
  depends_on = [null_resource.generate_ssh_config]
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
      "HOSTONLY_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v -e '^lo$' -e '^ens33$' | head -n 1)",
      "if [ -z \"$HOSTONLY_IFACE\" ]; then echo 'Error: Host-only network interface not found'; ip -o link show; exit 1; fi",
      # Configure Netplan with NAT handling external traffic
      "echo 'network:\n  version: 2\n  ethernets:\n    ens33:\n      dhcp4: true\n      dhcp6: false\n    ens32:\n      dhcp4: false\n      addresses: [${each.value.ip}/24]' | sudo tee /etc/netplan/00-hostonly.yaml",
      "sudo chmod 600 /etc/netplan/00-hostonly.yaml",
      # Apply Netplan configuration with error checking and delay
      "if ! sudo netplan apply; then echo 'Error: netplan apply failed'; cat /etc/netplan/00-hostonly.yaml; exit 1; fi",
      "sleep 5",
      # Set hostname
      "sudo hostnamectl set-hostname ${each.key}",
      # Verify hostname
      "echo 'Verifying hostname for ${each.key}'",
      "hostname | grep -i ${each.key} || echo 'Warning: Hostname mismatch for ${each.key}'",
      # Verify network interfaces
      "ip a show ens33 || echo 'Warning: ens33 not found'",
      "ip a show \"$HOSTONLY_IFACE\" || echo 'Warning: host-only interface not found'",
      # Verify IP
      "sleep 5",
      "ip a show \"$HOSTONLY_IFACE\" | grep ${each.value.ip} || echo 'Warning: host-only IP not set'",
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
      "sudo systemctl restart sshd",
      # Verify SSH public key
      "grep -q '${file("~/.ssh/id_ed25519_k8s-cluster.pub")}' ~/.ssh/authorized_keys || echo 'Warning: Failed to add SSH public key'"
    ]

    on_failure = continue
  }

  provisioner "local-exec" {
    command = <<EOT
      vmrun -T ws stop ${each.value.path} hard || true
    EOT
  }
}

resource "null_resource" "start_all_vms" {
  depends_on = [null_resource.configure_nodes]

  provisioner "local-exec" {
    command = <<EOT
      echo ">>> STEP: Starting all VMs after configuration..."
      ${join("\n", [for node in local.all_nodes : "vmrun -T ws start ${node.path} || echo 'Warning: Failed to start ${node.key}'"])}
      sleep 10
      echo "All VMs started."
      # Verify passwordless SSH
      ${join("\n", [for node in local.all_nodes : "ssh -o BatchMode=yes -o ConnectTimeout=10 vm${split(".", node.ip)[3]} hostname || echo 'Warning: Passwordless SSH failed for ${node.key}'"])}
    EOT
  }
}