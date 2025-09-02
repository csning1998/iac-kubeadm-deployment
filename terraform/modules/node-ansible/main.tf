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

/*
* Generate a ~/.ssh/iac-kubeadm-deployment_config file in the user's home directory with an alias and a specified public key
* for passwordless SSH using the alias (e.g., ssh vm200).
*/
resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/../../templates/ssh_config.tftpl", {
    nodes                = var.all_nodes,
    ssh_user             = var.vm_username,
    ssh_private_key_path = var.ssh_private_key_path
  })
  filename        = pathexpand("~/.ssh/iac-kubeadm-deployment_config")
  file_permission = "0600"
}

/*
* NOTE: Call functions in `utils_ssh.sh` via local-exec to manage the ~/.ssh/config file. 
* This avoids deletion during `terraform destroy()` in `scripts/terraform.sh`.
*/
resource "null_resource" "ssh_config_include" {
  depends_on = [local_file.ssh_config]

  provisioner "local-exec" {
    command     = ". ${path.root}/../../scripts/utils_ssh.sh && integrate_ssh_config"
    interpreter = ["/bin/bash", "-c"]
  }

  provisioner "local-exec" {
    when        = destroy
    command     = ". ${path.root}/../../scripts/utils_ssh.sh && deintegrate_ssh_config"
    interpreter = ["/bin/bash", "-c"]
  }
}

/*
* This makes sure this resource runs only after the "for_each" loop
* in "configure_nodes" has completed for all nodes.
*/
resource "null_resource" "prepare_ssh_access" {
  depends_on = [var.vm_status, null_resource.ssh_config_include]

  provisioner "local-exec" {
    command     = <<-EOT
      set -e
      echo ">>> Verifying VM liveness and preparing SSH access..."
      . ${path.root}/../../scripts/utils_ssh.sh
      bootstrap_ssh_known_hosts ${join(" ", [for node in var.all_nodes : node.ip])}
      echo ">>> Liveness check passed. SSH access is ready."
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
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
  content = templatefile("${path.module}/../../templates/inventory.yaml.tftpl", {
    master_nodes = local.master_nodes,
    worker_nodes = local.worker_nodes

    k8s_master_ips    = var.k8s_master_ips,
    k8s_ha_virtual_ip = var.k8s_ha_virtual_ip,
    k8s_pod_subnet    = var.k8s_pod_subnet,
    ansible_ssh_user  = var.vm_username,
    nat_subnet_prefix = var.nat_subnet_prefix
  })
  filename        = "${var.ansible_path}/inventory.yaml"
  file_permission = "0644"
}

resource "null_resource" "run_ansible" {
  depends_on = [null_resource.prepare_ssh_access, local_file.inventory]
  provisioner "local-exec" {

    working_dir = abspath("${path.root}/../../")

    command     = <<-EOT
      set -e
      ansible-playbook \
        -i ${var.ansible_path}/inventory.yaml \
        --private-key ${var.ssh_private_key_path} \
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

