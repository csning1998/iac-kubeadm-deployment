
source "qemu" "ubuntu-server" {

  # Guest OS & VM Naming
  vm_name           = "${var.vm_name}-qemu.qcow2"

  # ISO Configuration
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Virtual Hardware Configuration
  cpus           = var.cpus
  memory         = var.memory
  disk_size      = var.disk_size
  disk_interface = "virtio"
  net_device     = "virtio-net"
  headless       = true
  accelerator    = "kvm"

  # HTTP Content Delivery for cloud-init
  http_content = {
    "/user-data" = templatefile("${path.root}/http/user-data", {
      username      = var.ssh_username
      password_hash = var.ssh_password_hash
    })
    "/meta-data" = file("${path.root}/http/meta-data")
  }

  # Boot & Autoinstall Configuration
  boot_wait = "5s"
  boot_command = [
    "<wait2s>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/",
    "<f10>"
  ]

  # SSH Configuration for Provisioning
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "20m"

  # Shutdown Command
  shutdown_command = "sudo shutdown -P now"
  output_directory  = "output/ubuntu-server-qemu"
  format            = "qcow2"
}