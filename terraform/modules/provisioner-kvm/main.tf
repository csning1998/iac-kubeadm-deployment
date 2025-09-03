terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

data "local_file" "ssh_public_key" {
  filename = pathexpand(var.ssh_public_key_path)
}

resource "libvirt_network" "nat_net" {
  name      = var.nat_network_name
  mode      = "nat"
  bridge    = "virbr_nat" # Avoid conflict with default virbr0 on the Host
  addresses = [var.nat_network_cidr]
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}

resource "libvirt_network" "hostonly_net" {
  name      = var.hostonly_network_name
  mode      = "nat" # Use NAT to enable DHCP and DNS
  bridge    = "virbr_hostonly"
  addresses = [var.hostonly_network_cidr]
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}

resource "libvirt_volume" "os_disk" {
  for_each = var.all_nodes_map
  name     = "${each.key}-os.qcow2"
  pool     = var.libvirt_pool
  source   = var.qemu_base_image_path
  format   = "qcow2"
}

resource "libvirt_cloudinit_disk" "cloud_init" {
  for_each       = var.all_nodes_map
  name           = "${each.key}-cloud-init.iso"
  pool           = var.libvirt_pool
  user_data      = data.template_file.user_data[each.key].rendered
  network_config = data.template_file.network_config[each.key].rendered
}

data "template_file" "user_data" {
  for_each = var.all_nodes_map

  template = <<-EOT
    #cloud-config
    hostname: ${each.key}
    manage_etc_hosts: true
    users:
      - name: ${var.vm_username}
        passwd: "${var.vm_password}"
        lock_passwd: false
        sudo: ['ALL=(ALL) NOPASSWD:ALL']
        ssh_authorized_keys:
          - ${data.local_file.ssh_public_key.content}
  EOT
}

data "template_file" "network_config" {
  for_each = var.all_nodes_map
  template = <<-EOT
    #cloud-config
    version: 2
    renderer: networkd
    ethernets:
      all_interfaces:
        match:
          name: en*
        dhcp4: true
  EOT
}

resource "libvirt_domain" "nodes" {

  for_each = var.all_nodes_map

  name   = each.key
  memory = each.value.ram
  vcpu   = each.value.vcpu

  cloudinit = libvirt_cloudinit_disk.cloud_init[each.key].id

  network_interface {
    network_name = libvirt_network.nat_net.name
    addresses    = ["${var.nat_subnet_prefix}.${split(".", each.value.ip)[3]}"]
  }

  network_interface {
    network_name = libvirt_network.hostonly_net.name
    addresses    = [each.value.ip]
  }

  disk {
    volume_id = libvirt_volume.os_disk[each.key].id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type           = "vnc"
    listen_type    = "address"
    autoport       = true
    listen_address = "0.0.0.0"
  }

  video {
    type = "vga"
  }
}
