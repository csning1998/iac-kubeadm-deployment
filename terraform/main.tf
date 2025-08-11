terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
    ansible = {
      source  = "ansible/ansible"
      version = ">= 1.3.0"
    }
  }
}

locals {
  vms_dir = "${path.root}/vms"
  master_ip_list = var.master_ip_list
  worker_ip_list = var.worker_ip_list
  vmx_image_path = abspath("${path.root}/../packer/output/ubuntu-server-vmware/ubuntu-server-24-template-vmware.vmx")
  ansible_inventory_path = abspath("${path.root}/../ansible/")
  vault_pass_path = abspath("${path.root}/../vault_pass.txt")

  master_config = [
    for idx, ip in local.master_ip_list : {
      key       = "k8s-master-${format("%02d", idx)}"
      ip        = ip
      vcpu      = var.master_vcpu
      ram       = var.master_ram
      path      = "${local.vms_dir}/k8s-master-${format("%02d", idx)}/k8s-master-${format("%02d", idx)}.vmx"
    }
  ]

  workers_config = [
    for idx, ip in local.worker_ip_list : {
      key       = "k8s-worker-${format("%02d", idx)}"
      ip        = ip
      vcpu      = var.worker_vcpu
      ram       = var.worker_ram
      path      = "${local.vms_dir}/k8s-worker-${format("%02d", idx)}/k8s-worker-${format("%02d", idx)}.vmx"
    }
  ]

  all_nodes = concat(local.master_config, local.workers_config)
}

/*
Generate a `~/.ssh/config` file in the user's home directory with an alias and a specified public key
such that it allows for passwordless SSH using the alias (e.g., ssh vm200).
*/
resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/templates/ssh_config.tftpl", {
    nodes = local.all_nodes,
    ssh_user = var.vm_username,
    ssh_key_path = "~/.ssh/id_ed25519_k8s-cluster"
  })
  filename = pathexpand("~/.ssh/config")
  file_permission = "0600"

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ~/.ssh
      if [ ! -f ~/.ssh/id_ed25519_k8s-cluster ]; then
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_k8s-cluster -N "" -C "k8s-cluster-key"
      fi
    EOT
  }
}

resource "ansible_vault" "secrets" {
  vault_file          = "${local.ansible_inventory_path}/group_vars/vault.yml"
  vault_password_file = local.vault_pass_path
}

/*
Dynamically generate an inventory.yml file such that Ansible can SSH to virtual machines and execute playbooks.
*/
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

/*
NOTE: Using `local-exec` to start VMs as a workaround due to the lack of a stable
VMware Workstation provider. This is a known technical debt.
*/
resource "null_resource" "start_all_vms" {
  depends_on = [null_resource.configure_nodes, local_file.ssh_config]

  provisioner "local-exec" {
    command = <<EOT
      echo ">>> STEP: Starting all VMs after configuration..."
      ${join("\n", [for node in local.all_nodes : "vmrun -T ws start ${node.path} || echo 'Warning: Failed to start ${node.key}'"])}
      sleep 30
      echo "All VMs started."
    EOT
  }
}

resource "ansible_playbook" "setup_k8s" {
  depends_on = [null_resource.start_all_vms, ansible_vault.secrets]
  playbook   = "${local.ansible_inventory_path}/playbooks/setup_k8s.yml"
  name       = "vm${split(".", local.master_config[0].ip)[3]}"
  groups     = ["master", "workers"]
  extra_vars = {
    ansible_python_interpreter = "/usr/bin/python3"
  }
  vault_files         = ["${local.ansible_inventory_path}/group_vars/vault.yml"]
  vault_password_file = local.vault_pass_path
}