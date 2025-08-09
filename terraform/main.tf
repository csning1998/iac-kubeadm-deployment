terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

locals {
  ip_list = ["172.16.134.101", "172.16.134.102", "172.16.134.103"]
  vmx_image_path = abspath("${path.root}/../packer/output/ubuntu-server-vmware/ubuntu-server-24-template-vmware.vmx")
  vms_dir = "${path.root}/vms"

  nodes_list = [
    for idx in range(length(local.ip_list)) : {
      key     = "node-${idx + 1}"
      ip      = local.ip_list[idx]
    }
  ]
}

resource "null_resource" "k8s_nodes" {
  for_each = { for idx, node in local.nodes_list : node.key => node }

  # Clean up existing VM directory and clone VM
  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${local.vms_dir}/${each.key}
      mkdir -p ${local.vms_dir}/${each.key}
      vmrun -T ws clone ${local.vmx_image_path} ${local.vms_dir}/${each.key}/${each.key}.vmx full -cloneName=${each.key}
      # Add host-only network adapter (vmnet1) mimicking GUI
      sed -i '/^ethernet1\./d' ${local.vms_dir}/${each.key}/${each.key}.vmx
      echo 'ethernet1.present = "TRUE"' >> ${local.vms_dir}/${each.key}/${each.key}.vmx
      echo 'ethernet1.connectionType = "hostonly"' >> ${local.vms_dir}/${each.key}/${each.key}.vmx
      echo 'ethernet1.virtualDev = "e1000"' >> ${local.vms_dir}/${each.key}/${each.key}.vmx
    EOT
  }

  # Shut down VM if running
  provisioner "local-exec" {
    command = <<EOT
      vmrun -T ws list | grep ${each.key} && vmrun -T ws stop ${local.vms_dir}/${each.key}/${each.key}.vmx hard || true
      sleep 5
    EOT
  }

  # Start the VM to initialize
  provisioner "local-exec" {
    command = <<EOT
      vmrun -T ws start ${local.vms_dir}/${each.key}/${each.key}.vmx nogui
      sleep 5
    EOT
  }

  # Get NAT IP dynamically
  provisioner "local-exec" {
    command = <<EOT
      vmrun -T ws getGuestIPAddress ${local.vms_dir}/${each.key}/${each.key}.vmx -wait > ${local.vms_dir}/${each.key}/nat_ip.txt || true
    EOT
  }

  # Configure network and hostname
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
      "ip a show \"$HOSTONLY_IFACE\" | grep ${each.value.ip} || echo 'Warning: host-only IP not set'"
    ]
    on_failure = continue # Bypass SSH disconnection errors
  }

  # Ensure VM is stopped after configuration
  provisioner "local-exec" {
    command = <<EOT
      vmrun -T ws stop ${local.vms_dir}/${each.key}/${each.key}.vmx hard || true
    EOT
  }
}

# Global provisioner to start all VMs after configuration
resource "null_resource" "start_all_vms" {
  depends_on = [null_resource.k8s_nodes]

  provisioner "local-exec" {
    command = <<EOT
      echo ">>> STEP: Starting all VMs after configuration..."
      ${join("\n", [for node in local.nodes_list : "vmrun -T ws start ${local.vms_dir}/${node.key}/${node.key}.vmx nogui || echo 'Warning: Failed to start ${node.key}'"])}
      # Add delay to ensure network stability
      sleep 10
      echo "All VMs started."
    EOT
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