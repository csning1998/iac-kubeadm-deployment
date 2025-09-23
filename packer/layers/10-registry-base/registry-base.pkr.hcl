
build {
  sources = ["source.qemu.ubuntu-server-registry"]

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

    groups = [
      "10-registry-base"
    ]

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

  # # Provisioner to install Docker Engine
  # provisioner "shell" {
  #   inline = [
  #     "echo '>>> Installing Docker Engine...'",
  #     "sudo apt-get update",
  #     "sudo apt-get install -y ca-certificates curl",
  #     "sudo install -m 0755 -d /etc/apt/keyrings",
  #     "sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc",
  #     "sudo chmod a+r /etc/apt/keyrings/docker.asc",
  #     "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
  #     "sudo apt-get update",
  #     "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
  #     "echo '>>> Adding user to docker group...'",
  #     "sudo usermod -aG docker ${local.ssh_username}"
  #   ]
  # }

  # # Provisioner to verify Docker Engine
  # provisioner "shell" {
  #   environment_vars = [
  #     "SUDO_USER=${local.ssh_username}",
  #     "USER=${local.ssh_username}",
  #     "HOME=/home/${local.ssh_username}"
  #   ]

  #   inline = [
  #     "echo '>>> Verifying Docker Engine installation...'",
  #     "sudo -E -u ${local.ssh_username} newgrp docker <<'EOF'",
  #     "docker run hello-world",
  #     "EOF"
  #   ]
  # }
}