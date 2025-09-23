
build {
  sources = ["source.qemu.ubuntu-server"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y openssh-sftp-server",
      "sudo systemctl restart ssh"
    ]
  }

  # The Ansible provisioner block is used by all builders.
  provisioner "ansible" {
    playbook_file       = "../../../ansible/playbooks/00-provision-base-image.yaml"
    inventory_directory = "../../../ansible/"
    user                = local.ssh_username

    ansible_env_vars = [
      "ANSIBLE_CONFIG=../../../ansible.cfg"
    ]

    extra_arguments = [
      "--extra-vars", "expected_hostname=${local.vm_hostname}",
      "--extra-vars", "public_key_file=${local.ssh_public_key_path}",
      "--extra-vars", "ssh_user=${local.ssh_username}",
      "--extra-vars", "ansible_ssh_transfer_method=piped",
      "-v",
    ]
  }
}