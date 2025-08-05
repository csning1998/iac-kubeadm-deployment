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
  ip_list = ["192.168.56.101", "192.168.56.102", "192.168.56.103"]
  temp_ip = "192.168.56.88"
  ova_image_path = abspath("${path.root}/../packer/output/ubuntu-server/ubuntu-server-24-template.ova")

  nodes_list = [
    for idx in range(length(local.ip_list)) : {
      key     = "node-${idx + 1}"
      ip      = local.ip_list[idx]
      temp_ip = local.temp_ip
    }
  ]
}

resource "virtualbox_vm" "k8s_nodes" {
  for_each = { for idx, node in local.nodes_list : node.key => node }

  image  = local.ova_image_path
  name   = each.key
  cpus   = 2
  memory = "2048 mib"
  status = "poweroff" # Initially powered off, started by local-exec

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

# Shut down all VMs first
resource "null_resource" "shutdown_all_vms" {
  provisioner "local-exec" {
    command = join(" && ", [
      for node in local.nodes_list : "for i in {1..3}; do ( VBoxManage showvminfo ${node.key} --machinereadable 2>/dev/null | grep 'VMState=\"running\"' && VBoxManage controlvm ${node.key} poweroff || true ) && sleep 5; done"
    ])
  }
}

resource "null_resource" "sequential_provisioner" {
  for_each = { for idx, node in local.nodes_list : node.key => node }

  triggers = {
    vm_id = virtualbox_vm.k8s_nodes[each.key].id
  }

  depends_on = [null_resource.shutdown_all_vms]

  # Start the current VM (only if it's powered off)
  provisioner "local-exec" {
    command = "VBoxManage showvminfo ${each.key} --machinereadable 2>/dev/null | grep 'VMState=\"poweroff\"' && VBoxManage startvm ${each.key} --type headless && sleep 20 || true"
  }

  # Configure IP and hostname
  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = var.vm_username
      password = var.vm_password
      host     = each.value.temp_ip
      port     = 22
      timeout  = "10m"
      agent    = true
    }
    inline = [
      # Wait for SSH and network to stabilize
      "sleep 20",
      # Clear cloud-init state to prevent reset
      "sudo cloud-init clean --logs || true",
      "sudo systemctl disable cloud-init || true",
      "sudo systemctl stop cloud-init || true",
      "sudo touch /etc/cloud/cloud-init.disabled || true",
      # Back up and remove the enp0s8 configuration from 50-cloud-init.yaml
      "sudo cp /etc/netplan/50-cloud-init.yaml /etc/netplan/50-cloud-init.yaml.bak || true",
      "sudo sed -i '/enp0s8:/,+4d' /etc/netplan/50-cloud-init.yaml || true",
      # Verify removal
      "sudo cat /etc/netplan/50-cloud-init.yaml || true",
      # Create 99-custom.yaml
      "echo 'network:\n  version: 2\n  ethernets:\n    enp0s8:\n      dhcp4: no\n      addresses: [${each.value.ip}/24]\n      routes:\n        - to: default\n          via: 192.168.56.1\n      nameservers:\n        addresses: [8.8.8.8]' | sudo tee /etc/netplan/99-custom.yaml",
      "sudo chmod 600 /etc/netplan/99-custom.yaml",
      "sudo hostnamectl set-hostname ${each.key}",
      # Verify hostname
      "echo 'Verifying hostname for ${each.key}'",
      "hostname | grep -i ${each.key} || echo 'Warning: Hostname mismatch for ${each.key}'",
      # Verify 99-custom.yaml
      "sudo cat /etc/netplan/50-cloud-init.yaml || true",
      # Apply Netplan configuration
      "sudo netplan apply || true",
      # Verify IP
      "sleep 10",
      "ip a show enp0s8 | grep ${each.value.ip} || true"
    ]
    on_failure = continue # Bypass SSH disconnection errors
  }
}

output "instance_details" {
  description = "Connection details and IP addresses for the deployed VMs"
  sensitive   = true
  value = {
    for key, node in local.nodes_list :
    key => {
      ip_address   = node.ip
      ssh_command  = "ssh ${var.vm_username}@${node.ip}"
    }
  }
}