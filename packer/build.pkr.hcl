locals {
  
  source_map = {
    workstation = "source.vmware-iso.ubuntu-server"
    kvm         = "source.qemu.ubuntu-server"
  }

  active_source = local.source_map[var.provider]
}

build {

  sources = [local.active_source]

  # The Ansible provisioner block is used by all builders.
  provisioner "ansible" {
    playbook_file       = "../ansible/playbooks/00-provision-base-image.yaml"
    inventory_directory = "../ansible/"
    user                = var.ssh_username

    ansible_env_vars = [
      "ANSIBLE_CONFIG=../ansible.cfg"
    ]

    extra_arguments = [
      "--extra-vars", "expected_hostname=${var.vm_name}",
      "--extra-vars", "public_key_file=${var.ssh_public_key_path}",
      "--extra-vars", "ssh_user=${var.ssh_username}",
      "-v",
    ]
  }
}