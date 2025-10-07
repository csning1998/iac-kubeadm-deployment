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
  filename = pathexpand(var.credentials.ssh_public_key_path)
}

resource "libvirt_network" "nat_net" {
  name      = var.libvirt_infrastructure.network.nat.name
  mode      = "nat"
  bridge    = var.libvirt_infrastructure.network.nat.bridge_name
  addresses = [var.libvirt_infrastructure.network.nat.cidr]
  autostart = true
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}

resource "libvirt_network" "hostonly_net" {
  name      = var.libvirt_infrastructure.network.hostonly.name
  mode      = "route" # To let external network accesses VM directly via IP address
  bridge    = var.libvirt_infrastructure.network.hostonly.bridge_name
  addresses = [var.libvirt_infrastructure.network.hostonly.cidr]
  autostart = true
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}

resource "libvirt_pool" "storage_pool" {
  name = var.libvirt_infrastructure.storage_pool_name
  type = "dir"
  target {
    path = abspath("/var/lib/libvirt/images/${var.libvirt_infrastructure.storage_pool_name}")
  }
}

resource "libvirt_volume" "os_disk" {

  depends_on = [libvirt_pool.storage_pool]

  for_each = var.vm_config.all_nodes_map
  name     = "${each.key}-os.qcow2"
  pool     = libvirt_pool.storage_pool.name
  source   = var.vm_config.base_image_path
  format   = "qcow2"
}

resource "libvirt_cloudinit_disk" "cloud_init" {

  depends_on = [libvirt_pool.storage_pool]

  for_each = var.vm_config.all_nodes_map
  name     = "${each.key}-cloud-init.iso"
  pool     = libvirt_pool.storage_pool.name
  user_data = templatefile("${path.root}/../../templates/user_data.tftpl", {
    hostname       = each.key
    vm_username    = var.credentials.username
    vm_password    = var.credentials.password
    ssh_public_key = data.local_file.ssh_public_key.content
  })

  network_config = templatefile("${path.root}/../../templates/network_config.tftpl", {})
}

resource "libvirt_domain" "nodes" {

  for_each = var.vm_config.all_nodes_map

  autostart = false # Set to true to start the domain on host boot up. If not specified false is assumed.

  name   = each.key
  memory = each.value.ram
  vcpu   = each.value.vcpu

  cloudinit = libvirt_cloudinit_disk.cloud_init[each.key].id

  network_interface {
    network_name = libvirt_network.nat_net.name
    addresses    = ["${var.libvirt_infrastructure.network.nat.subnet_prefix}.${split(".", each.value.ip)[3]}"]
  }

  network_interface {
    network_name = libvirt_network.hostonly_net.name
    addresses    = [each.value.ip]
  }

  disk {
    volume_id = libvirt_volume.os_disk[each.key].id
  }

  # Serial console (ttyS0), often used for basic interaction and debugging.
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  # Virtio console (hvc0), expected by modern cloud-init versions to avoid startup hangs.
  # This is the critical fix: https://bugs.launchpad.net/cloud-images/+bug/1573095
  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
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

