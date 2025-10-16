
# This file defines the single, data-driven build block.

packer {
  required_plugins {
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

build {
  sources = ["source.qemu.ubuntu"]

  # --- Common Provisioners ---
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y openssh-sftp-server",
      "sudo systemctl restart ssh"
    ]
  }

  provisioner "ansible" {
    playbook_file       = "../ansible/playbooks/00-provision-base-image.yaml"
    inventory_directory = "../ansible/"
    user                = local.ssh_username

    # Ansible group is dynamically set by a variable.
    groups = [
      var.build_spec.suffix
    ]
    ansible_env_vars = [
      "ANSIBLE_CONFIG=../ansible.cfg"
    ]
    extra_arguments = [
      "--extra-vars", "expected_hostname=${local.final_vm_name}",
      "--extra-vars", "public_key_file=${local.ssh_public_key_path}",
      "--extra-vars", "ssh_user=${local.ssh_username}",
      "--extra-vars", "ansible_ssh_transfer_method=piped",
      "-v",
    ]
  }
}