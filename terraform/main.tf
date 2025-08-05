terraform {
  required_providers {
    virtualbox = {
      source  = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

locals {
  nodes = {
    "node-1" = {
      ip       = "192.168.56.101"
      temp_ip  = "192.168.56.88"
    }
    "node-2" = {
      ip       = "192.168.56.102"
      temp_ip  = "192.168.56.88"
    }
  }
  ova_image_path = abspath("${path.root}/../packer/output/ubuntu-server/ubuntu-server-24-template.ova")
}

resource "virtualbox_vm" "k8s_nodes" {
  for_each = local.nodes

  image  = local.ova_image_path
  name   = each.key
  cpus   = 2
  memory = "2048 mib"
  status = "running"

  network_adapter {
    type   = "nat"
    device = "VirtIO"
  }

  network_adapter {
    type           = "hostonly"
    host_interface = "vboxnet0"
    device         = "VirtIO"
  }
}

resource "null_resource" "configure_ip" {
  for_each = virtualbox_vm.k8s_nodes

  triggers = {
    vm_id = each.value.id
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = var.vm_username
      password = var.vm_password
      host     = local.nodes[each.key].temp_ip
      port     = 22
      timeout  = "5m"
    }
    inline = [
      "echo 'SSH connection successful. Applying configuration for ${each.key}'",
      "sudo hostnamectl set-hostname ${each.key}",
      "echo 'network:\n  version: 2\n  ethernets:\n    enp0s8:\n      dhcp4: no\n      addresses: [${local.nodes[each.key].ip}/24]\n      gateway4: 192.168.56.1\n      nameservers:\n        addresses: [8.8.8.8]' | sudo tee /etc/netplan/99-custom.yaml",
      "sudo netplan apply",
      "ip a show enp0s8 | grep ${local.nodes[each.key].ip}"
    ]
  }
}

output "instance_details" {
  description = "Connection details and IP addresses for the deployed VMs"
  sensitive   = true
  value = {
    for key, node in local.nodes :
    key => {
      ip_address   = node.ip
      ssh_command  = "ssh ${var.vm_username}@${node.ip}"
    }
  }
}