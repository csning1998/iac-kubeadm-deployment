
source "virtualbox-iso" "ubuntu-server" {
  # Guest OS & VM Naming
  guest_os_type = var.guest_os_type
  vm_name       = var.vm_name

  # ISO Configuration
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # Hardware Configuration
  cpus      = var.cpus
  memory    = var.memory
  disk_size = var.disk_size
  headless  = false

  # Hardware Interfaces
  hard_drive_interface     = "sata"
  hard_drive_discard       = true
  hard_drive_nonrotational = true
  gfx_controller           = "vboxsvga"

  # guest_additions_mode = "upload"
  # guest_additions_path = "/tmp/VBoxGuestAdditions.iso"
  
  # HTTP Content Delivery for cloud-init
  http_content = {
    "/user-data" = templatefile("${path.root}/http/user-data", {
      username      = var.ssh_username
      password_hash = var.ssh_password_hash
    })
    "/meta-data" = file("${path.root}/http/meta-data")
  }

  # Boot Command with wait time
  boot_wait    = "5s"
  boot_command = [
    "<wait2s>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/",
    "<f10>"
  ]

  vboxmanage = [
    ["modifyvm", "{{.Name}}", "--vram", "20"],
    ["modifyvm", "{{.Name}}", "--nic2", "hostonly", "--hostonlyadapter2", "vboxnet0"]
  ]

  # SSH Configuration for Provisioning
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "99m"

  # Shutdown & Output Configuration
  shutdown_command = "sudo shutdown -P now"
  output_directory = "output/ubuntu-server"
  format           = "ova"
  keep_registered  = false
}

build {
  sources = ["source.virtualbox-iso.ubuntu-server"]

  provisioner "ansible" {
    playbook_file = "./playbooks/provision.yml"
    user          = var.ssh_username
    extra_arguments = [
      "--extra-vars", "ansible_become_pass=${var.ssh_password}"
    ]
  }
}
