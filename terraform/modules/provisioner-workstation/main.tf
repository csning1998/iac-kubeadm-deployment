
locals {
  master_config = [
    for idx, ip in var.master_ip_list : {
      key  = "k8s-master-${format("%02d", idx)}"
      ip   = ip
      vcpu = var.master_vcpu
      ram  = var.master_ram
      path = "${var.vms_dir}/k8s-master-${format("%02d", idx)}/k8s-master-${format("%02d", idx)}.vmx"
    }
  ]
  workers_config = [
    for idx, ip in var.worker_ip_list : {
      key  = "k8s-worker-${format("%02d", idx)}"
      ip   = ip
      vcpu = var.worker_vcpu
      ram  = var.worker_ram
      path = "${var.vms_dir}/k8s-worker-${format("%02d", idx)}/k8s-worker-${format("%02d", idx)}.vmx"
    }
  ]
  all_nodes = concat(local.master_config, local.workers_config)
}

/*
* NOTE: Using local-exec and remote-exec to configure VMs as a workaround 
* due to the lack of a stable VMware Workstation provider. 
* This is a known technical debt.
*/
resource "null_resource" "configure_nodes" {
  for_each = { for node in local.all_nodes : node.key => node }

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
      vmrun -T ws getGuestIPAddress ${each.value.path} -wait > ${var.vms_dir}/${each.key}/nat_ip.txt
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
      "sudo touch /etc/cloud/cloud-init.disabled || true",
      "sudo rm -f /etc/netplan/*.yaml",
      "sudo rm -f /etc/machine-id",
      "sudo systemd-machine-id-setup",

      "for i in {1..5}; do NAT_IFACE=$(ip -o -4 addr show | grep 'inet 172.16.86.' | awk '{print $2}'); [ -n \"$NAT_IFACE\" ] && break; sleep 2; done",
      "if [ -z \"$NAT_IFACE\" ]; then echo 'Error: Could not find NAT interface'; ip addr; exit 1; fi",
      "HOSTONLY_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v -e '^lo$' -e \"^$NAT_IFACE$\")",
      "if [ -z \"$HOSTONLY_IFACE\" ]; then echo 'Error: Could not find Host-only interface'; ip addr; exit 1; fi",

      "sudo ip addr flush dev $NAT_IFACE || true",
      "sudo ip addr flush dev $HOSTONLY_IFACE || true",
      "sleep 2",

      "echo 'network:",
      "  version: 2",
      "  renderer: networkd",
      "  ethernets:",
      "    '$NAT_IFACE':",
      "      dhcp4: false",
      "      addresses: [${var.nat_subnet_prefix}.${split(".", each.value.ip)[3]}/24]",
      "      routes:",
      "        - to: default",
      "          via: ${var.nat_gateway}",
      "      nameservers:",
      "        addresses: [8.8.8.8, 8.8.4.4]",
      "      dhcp6: false",
      "    '$HOSTONLY_IFACE':",
      "      dhcp4: false",
      "      addresses: [${each.value.ip}/24]",
      "      dhcp6: false",
      "      optional: true",
      "' | sudo tee /etc/netplan/00-installer-config.yaml",

      "sudo chmod 600 /etc/netplan/00-installer-config.yaml",
      "sudo netplan apply || { echo 'Error: netplan apply failed'; cat /etc/netplan/00-installer-config.yaml; exit 1; }",
      "sleep 5",
      "sudo hostnamectl set-hostname ${each.key}",
      "chmod 755 /home/${var.vm_username}",
      "sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config",
      "sudo sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config",
      "sudo systemctl restart sshd"
    ]
    on_failure = continue
  }
}
