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

  # Final Boot Command based on your discovery
  boot_wait = "5s"
  boot_command = [
    "<wait>e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/",
    "<f10>"
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
    playbook_file = "./playbooks/provision.yml"
    # Pass the sudo password to Ansible
    extra_arguments = [
      "-e", format("ansible_become_pass=%s", var.user_password)
    ]
  }

  # Post-Processor to compress the artifact (optional)
  post-processor "compress" {
    output = "output/ubuntu-24.04/golden-image.ova.gz"
  }
}