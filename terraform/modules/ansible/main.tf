terraform {
  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = ">= 1.3.0"
    }
  }
}


/*
* Dynamically generate an inventory for Ansible to SSH to virtual machines and execute playbooks.
*/
resource "ansible_host" "nodes" {
  for_each = { for node in var.all_nodes : node.key => node }
  name     = "vm${split(".", each.value.ip)[3]}"
  groups   = startswith(each.value.key, "k8s-master") ? ["master"] : ["workers"]
  variables = {
    ansible_host                  = each.value.ip
    ansible_ssh_user              = var.vm_username
    ansible_ssh_private_key_file  = "~/.ssh/id_ed25519_k8s-cluster"
    ansible_ssh_extra_args        = "-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/k8s_cluster_config"
  }
}

resource "ansible_vault" "secrets" {
  vault_file          = "${var.ansible_path}/group_vars/vault.yml"
  vault_password_file = var.vault_pass_path
}

/*
Generate Ansible inventory file from template
*/
resource "local_file" "inventory" {
  content = templatefile("${path.module}/../../templates/inventory.yml.tftpl", {
    master_ips = var.master_config[*].ip,
    worker_ips = var.worker_config[*].ip,
    ssh_user   = var.vm_username,
  })
  filename = "${var.ansible_path}/inventory.yml"
  file_permission = "0644"
}

resource "null_resource" "run_ansible" {
  depends_on = [var.vm_status, ansible_vault.secrets, local_file.inventory]
  provisioner "local-exec" {
    command = <<EOT
      ansible-playbook -i ${var.ansible_path}/inventory.yml ${var.ansible_path}/playbooks/00-provision_k8s.yml --vault-password-file ${var.vault_pass_path} -vv
    EOT
  }
}

# resource "ansible_playbook" "provision_k8s" {
#   for_each            = { for node in var.all_nodes : node.key => node }
#   depends_on          = [var.vm_status, ansible_vault.secrets]
#   playbook            = "${var.ansible_path}/playbooks/00-provision_k8s.yml"
#   name                = "vm${split(".", each.value.ip)[3]}"
#   groups              = ["master", "workers"]
#   vault_files         = ["${var.ansible_path}/group_vars/vault.yml"]
#   vault_password_file = var.vault_pass_path
#   verbosity           = 2  # Use verbose output for Ansible tasks
#   extra_vars          = {
#     ansible_python_interpreter = "/usr/bin/python3"
#     ansible_ssh_extra_args    = "-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts"
#   }
# }

