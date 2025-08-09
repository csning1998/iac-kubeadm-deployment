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

resource "null_resource" "configure_nodes" {
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
      vmrun -T ws start ${each.value.path}
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
      "sleep 5",
      "sudo cloud-init clean --logs || true",
      "sudo systemctl disable cloud-init || true",
      "sudo systemctl stop cloud-init || true",
      "sudo touch /etc/cloud/cloud-init.disabled || true",
      "sudo modprobe e1000 || true",
      "sudo udevadm trigger || true",
      "HOSTONLY_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v -e '^lo$' -e '^ens33$' | head -n 1)",
      "if [ -z \"$HOSTONLY_IFACE\" ]; then echo 'Error: Host-only network interface not found'; ip -o link show; exit 1; fi",
      "echo 'network:\n  version: 2\n  ethernets:\n    ens33:\n      dhcp4: true\n      dhcp6: false\n    ens32:\n      dhcp4: false\n      addresses: [${each.value.ip}/24]' | sudo tee /etc/netplan/00-hostonly.yaml",
      "sudo chmod 600 /etc/netplan/00-hostonly.yaml",
      "if ! sudo netplan apply; then echo 'Error: netplan apply failed'; cat /etc/netplan/00-hostonly.yaml; exit 1; fi",
      "sleep 5",
      "sudo hostnamectl set-hostname ${each.key}",
      "echo 'Verifying hostname for ${each.key}'",
      "hostname | grep -i ${each.key} || echo 'Warning: Hostname mismatch for ${each.key}'",
      "ip a show ens33 || echo 'Warning: ens33 not found'",
      "ip a show \"$HOSTONLY_IFACE\" || echo 'Warning: host-only interface not found'",
      "sleep 5",
      "ip a show \"$HOSTONLY_IFACE\" | grep ${each.value.ip} || echo 'Warning: host-only IP not set'"
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
    EOT
  }
}