# This file defines the single, data-driven QEMU source.

locals {
  ssh_username        = vault("secret/data/iac-kubeadm-deployment/variables", "ssh_username")
  ssh_password        = vault("secret/data/iac-kubeadm-deployment/variables", "ssh_password")
  ssh_password_hash   = vault("secret/data/iac-kubeadm-deployment/variables", "ssh_password_hash")
  ssh_public_key_path = vault("secret/data/iac-kubeadm-deployment/variables", "ssh_public_key_path")

  # The final hostname is dynamically composed from variables.
  final_vm_name = "${var.vm_name}-${var.build_name_suffix}"
}

source "qemu" "ubuntu" {
  # --- Dynamic Settings from Variables ---
  vm_name          = local.final_vm_name
  output_directory = "./output/${var.build_name_suffix}"
  vnc_port_min     = var.vnc_port
  vnc_port_max     = var.vnc_port

  # --- Common Settings from Variables ---
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum
  cpus         = var.cpus
  memory       = var.memory
  disk_size    = var.disk_size

  # --- Common Hardcoded Settings ---
  disk_interface = "virtio"
  net_bridge     = "virbr0"
  net_device     = "virtio-net"
  accelerator    = "kvm"
  qemu_binary    = "/usr/bin/qemu-system-x86_64"
  qemuargs       = [["-cpu", "host"]]
  headless       = true
  format         = "qcow2"

  # --- Cloud-Init & Autoinstall ---
  http_directory = "./http"
  cd_content = {
    "/user-data" = templatefile("${path.root}/http/user-data", {
      hostname      = local.final_vm_name
      username      = local.ssh_username
      password_hash = local.ssh_password_hash
    })
    "/meta-data" = file("${path.root}/http/meta-data")
  }
  cd_label = "cidata"

  # --- Boot & SSH ---
  boot_wait = "5s"
  boot_command = [
    "<wait2s>", "e<wait>", "<down><down><down><end>",
    " autoinstall ds=nocloud;", "<f10>"
  ]
  ssh_username     = local.ssh_username
  ssh_password     = local.ssh_password
  ssh_timeout      = "10m"
  shutdown_command = "sudo shutdown -P now"
}