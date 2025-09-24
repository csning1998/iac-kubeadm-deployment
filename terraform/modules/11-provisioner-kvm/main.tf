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
  name      = var.libvirt_nat_network_name
  mode      = "nat"
  bridge    = "virbr_nat" # Avoid conflict with default virbr0 on the Host
  addresses = [var.libvirt_nat_network_cidr]
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}

resource "libvirt_network" "hostonly_net" {
  name      = var.libvirt_hostonly_network_name
  mode      = "nat" # Use NAT to enable DHCP and DNS
  bridge    = "virbr_hostonly"
  addresses = [var.libvirt_hostonly_network_cidr]
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}

resource "libvirt_pool" "kube_pool" {
  name = var.libvirt_storage_pool_name
  type = "dir"
  target {
    path = abspath("/var/lib/libvirt/images")
  }
}

resource "libvirt_volume" "os_disk" {

  depends_on = [libvirt_pool.kube_pool]

  for_each = var.all_nodes_map
  name     = "${each.key}-os.qcow2"
  pool     = libvirt_pool.kube_pool.name
  source   = var.libvirt_vm_base_image_path
  format   = "qcow2"
}

resource "libvirt_cloudinit_disk" "cloud_init" {

  depends_on = [libvirt_pool.kube_pool]

  for_each = var.all_nodes_map
  name     = "${each.key}-cloud-init.iso"
  pool     = libvirt_pool.kube_pool.name
  user_data = templatefile("${path.root}/../../templates/user_data.tftpl", {
    hostname       = each.key
    vm_username    = var.vm_username
    vm_password    = var.vm_password
    ssh_public_key = data.local_file.ssh_public_key.content
  })

  network_config = templatefile("${path.root}/../../templates/network_config.tftpl", {})
}

resource "libvirt_domain" "nodes" {

  for_each = var.all_nodes_map

  autostart = false # Set to true to start the domain on host boot up. If not specified false is assumed.

  name   = each.key
  memory = each.value.ram
  vcpu   = each.value.vcpu

  cloudinit = libvirt_cloudinit_disk.cloud_init[each.key].id

  network_interface {
    network_name = libvirt_network.nat_net.name
    addresses    = ["${var.libvirt_nat_network_subnet_prefix}.${split(".", each.value.ip)[3]}"]
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
