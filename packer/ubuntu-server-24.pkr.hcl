
source "vmware-iso" "ubuntu-server" {
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
  disk_type_id         = "0" # Growable virtual disk contained in a single file (monolithic sparse).
  disk_adapter_type    = "scsi"
  network              = "nat" # For external internet connection during installation.
  network_adapter_type = "e1000" # Recommended values are e1000 and vmxnet3. Defaults to e1000.
  
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

  # SSH Configuration for Provisioning
  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "10m"

  # Shutdown & Output Configuration
  shutdown_command = "sudo shutdown -P now"
  output_directory = "output/ubuntu-server-vmware"
  format           = "vmx"
  keep_registered  = false
}

build {
  sources = ["source.vmware-iso.ubuntu-server"]

  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/00-main.yml"
    inventory_directory = "../ansible/"

    user          = var.ssh_username
    
    extra_arguments = [
      "--extra-vars", "ansible_become_pass=${var.ssh_password}",
      "--extra-vars", "expected_hostname=${var.vm_name}",
      "--extra-vars", "ssh_user=${var.ssh_username}",
      "-v",
      # "-vv",
      # "-vvv",
    ]
  }
}
