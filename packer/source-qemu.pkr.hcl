
source "qemu" "ubuntu-server" {

  # Guest OS & VM Naming
  vm_name = "${var.vm_name}-qemu.qcow2"

  # ISO Configuration
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Virtual Hardware Configuration
  cpus           = var.cpus
  memory         = var.memory
  disk_size      = var.disk_size
  disk_interface = "virtio"
  net_bridge     = "virbr0"
  accelerator    = "kvm"
  qemu_binary    = "/usr/bin/qemu-system-x86_64"
  qemuargs = [
    ["-cpu", "host"]
  ]

  headless = true

  http_directory = "http"
  cd_content = {
    "/user-data" = templatefile("${path.root}/http/user-data", {
      username      = var.ssh_username
      password_hash = var.ssh_password_hash
    })
    "/meta-data" = file("${path.root}/http/meta-data")
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

  net_device   = "virtio-net"
  vnc_port_min = "5999"
  vnc_port_max = "5999"

  # SSH Configuration for Provisioning
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "10m"

  # Shutdown Command
  shutdown_command = "sudo shutdown -P now"
  output_directory = "output/ubuntu-server-qemu"
  format           = "qcow2"
}