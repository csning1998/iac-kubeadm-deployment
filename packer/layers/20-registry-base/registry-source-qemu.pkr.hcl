/*
 * Define the source of Vault data
*/
/*
 * Define the source of Vault data
*/
locals {
  ssh_username        = vault("secret/data/iac-kubeadm-deployment/variables", "ssh_username")
  ssh_password        = vault("secret/data/iac-kubeadm-deployment/variables", "ssh_password")
  ssh_password_hash   = vault("secret/data/iac-kubeadm-deployment/variables", "ssh_password_hash")
  ssh_public_key_path = vault("secret/data/iac-kubeadm-deployment/variables", "ssh_public_key_path")
  vm_hostname         = "${var.vm_name}-20-registry-base"
}

source "qemu" "ubuntu-server-registry" {

  # Guest OS & VM Naming
  vm_name = "${local.vm_hostname}.qcow2"

  # ISO Configuration
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Virtual Hardware Configuration
  cpus           = var.cpus
  memory         = var.memory
  disk_size      = var.disk_size
  disk_interface = "virtio"
  net_bridge     = "virbr0"
  net_device     = "virtio-net"
  accelerator    = "kvm"
  qemu_binary    = "/usr/bin/qemu-system-x86_64"
  qemuargs = [
    ["-cpu", "host"]
  ]

  headless = true

  http_directory = "../../http"
  cd_content = {
    "/user-data" = templatefile("${path.root}/../../http/user-data", {
      hostname      = local.vm_hostname
      username      = local.ssh_username
      password_hash = local.ssh_password_hash
    })
    "/meta-data" = file("${path.root}/../../http/meta-data")
  }
  cd_label = "cidata"

  # Boot & Autoinstall Configuration
  boot_wait = "5s"
  boot_command = [
    "<wait2s>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud;",
    "<f10>"
  ]

  vnc_port_min = "5998"
  vnc_port_max = "5998"

  # SSH Configuration for Provisioning
  ssh_username = local.ssh_username
  ssh_password = local.ssh_password
  ssh_timeout  = "10m"

  # Shutdown Command
  shutdown_command = "sudo shutdown -P now"
  output_directory = "../../output/20-registry-base"
  format           = "qcow2"
}