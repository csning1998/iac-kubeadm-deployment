resource "ansible_host" "nodes" {
  for_each = { for node in local.all_nodes : node.key => node }
  name     = "vm${split(".", each.value.ip)[3]}"
  groups   = startswith(each.value.key, "k8s-master") ? ["master"] : ["workers"]
  variables = {
    ansible_host                  = each.value.ip
    ansible_ssh_user              = var.vm_username
    ansible_ssh_private_key_file  = "~/.ssh/id_ed25519_k8s-cluster"
    ansible_ssh_extra_args        = "-o StrictHostKeyChecking=accept-new"
  }
}

resource "ansible_vault" "secrets" {
  vault_file          = "${local.ansible_path}/group_vars/vault.yml"
  vault_password_file = local.vault_pass_path
}

resource "ansible_playbook" "setup_k8s" {
  depends_on = [null_resource.start_all_vms, ansible_vault.secrets]
  playbook   = "${local.ansible_path}/playbooks/setup_k8s.yml"
  name       = "vm${split(".", local.master_config[0].ip)[3]}"
  groups     = ["master", "workers"]
  extra_vars = {
    ansible_python_interpreter = "/usr/bin/python3"
  }
  vault_files         = ["${local.ansible_path}/group_vars/vault.yml"]
  vault_password_file = local.vault_pass_path
  verbosity           = 3  # Enable verbose output for Ansible
}