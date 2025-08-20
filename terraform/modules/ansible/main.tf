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
  name     = each.value.key
  groups   = startswith(each.value.key, "k8s-master") ? ["master"] : ["workers"]
  variables = {
    advertise_ip = each.value.ip
  }
}

resource "ansible_vault" "secrets" {
  vault_file          = "${var.ansible_path}/group_vars/vault.yaml"
  vault_password_file = var.vault_pass_path
}

/*
* Generate the parameters that are necessary for Ansible inventory
*/
locals {
  master_nodes = [
    for node in var.all_nodes : node if startswith(node.key, "k8s-master")
  ]
  worker_nodes = [
    for node in var.all_nodes : node if startswith(node.key, "k8s-worker")
  ]
}

/*
* Generate the Ansible inventory file from template
*/
resource "local_file" "inventory" {
  content = templatefile("${path.root}/templates/inventory.yaml.tftpl", {
    master_nodes = local.master_nodes,
    worker_nodes = local.worker_nodes
  })
  filename        = "${var.ansible_path}/inventory.yaml"
  file_permission = "0644"
}

resource "null_resource" "run_ansible" {
  depends_on = [var.vm_status, ansible_vault.secrets, local_file.inventory]
  provisioner "local-exec" {
    command     = <<-EOT
      set -e
      cd ..
      ansible-playbook \
        -i ${var.ansible_path}/inventory.yaml \
        --private-key ${var.ssh_private_key_path} \
        --vault-password-file ${var.vault_pass_path} \
        --extra-vars "ansible_ssh_user=${var.vm_username}" \
        -vv \
        ${var.ansible_path}/playbooks/10-provision-cluster.yaml
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
#       . ${path.root}/../scripts/utils_ssh.sh && bootstrap_ssh_known_hosts ${join(" ", [for node in var.all_nodes : node.ip])}

/*
 * Execute Ansible playbook using ansible_playbook resource
 */
# resource "ansible_playbook" "provision_k8s" {
#   for_each            = { for node in var.all_nodes : node.key => node }
#   depends_on          = [var.vm_status, ansible_vault.secrets]
#   playbook            = "${var.ansible_path}/playbooks/10-provision-cluster.yaml"
#   name                = "vm${split(".", each.value.ip)[3]}"
#   groups              = ["master", "workers"]
#   vault_files         = ["${var.ansible_path}/group_vars/vault.yaml"]
#   vault_password_file = var.vault_pass_path
#   verbosity           = 2  # Use verbose output for Ansible tasks
#   extra_vars          = {
#     ansible_python_interpreter = "/usr/bin/python3"
#     ansible_ssh_extra_args    = "-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=~/.ssh/known_hosts"
#   }
# }

