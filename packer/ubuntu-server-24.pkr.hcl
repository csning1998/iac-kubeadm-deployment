packer {
  required_plugins {
    virtualbox = {
      version = "~> 1"
      source  = "github.com/hashicorp/virtualbox"
    }
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

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

  # HTTP Content Delivery for cloud-init
  http_content = {
    "/user-data" = templatefile("${path.root}/http/user-data", {
      username      = var.ssh_username
      password_hash = var.user_password_hash
    })
    "/meta-data" = file("${path.root}/http/meta-data")
  }

  # Boot Command with wait time
  boot_command = [
    "<wait5s>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/",
    "<f10>"
  ]

  # Explicitly manage all storage on a single, modern SATA controller.
  vboxmanage = [
    ["storageattach", "{{.Name}}", "--storagectl", "IDE Controller", "--port", "1", "--device", "0", "--type", "dvddrive", "--medium", "/usr/share/virtualbox/VBoxGuestAdditions.iso"]
  ]

  # SSH Configuration for Provisioning
  ssh_username = var.ssh_username
  ssh_password = var.user_password
  ssh_timeout  = "30m"

  # Shutdown & Output Configuration
  shutdown_command = "sudo /sbin/shutdown -hP now"
  output_directory = "output/ubuntu-24.04"
  format           = "ova"
}

build {
  sources = ["source.virtualbox-iso.ubuntu-server"]

  provisioner "ansible" {
    playbook_file   = "./playbooks/provision.yml"
    extra_arguments = [
      "-e", format("ansible_become_pass=%s", var.user_password)
    ]
  }
}