terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
  }
}

locals {
  vms_dir = "${path.root}/vms"
  master_ip_list = var.master_ip_list
  worker_ip_list = var.worker_ip_list
  vmx_image_path = abspath("${path.root}/../packer/output/ubuntu-server-vmware/ubuntu-server-24-template-vmware.vmx")
  ansible_inventory_path = abspath("${path.root}/../ansible/")

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

resource "null_resource" "generate_ssh_config" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ~/.ssh
      if [ ! -f ~/.ssh/id_ed25519_k8s-cluster ]; then
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_k8s-cluster -N "" -C "k8s-cluster-key"
      fi
      echo "# SSH configuration for Kubernetes cluster" > ~/.ssh/config
      chmod 600 ~/.ssh/config
      ${join("\n", [
        for node in local.all_nodes :
        "echo 'Host vm${split(".", node.ip)[3]}\n  HostName ${node.ip}\n  User ${var.vm_username}\n  IdentityFile ~/.ssh/id_ed25519_k8s-cluster' >> ~/.ssh/config"
      ])}
    EOT
  }
}

resource "null_resource" "generate_inventory" {
  depends_on = [null_resource.configure_nodes]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${local.ansible_inventory_path}
      [ -f ${local.ansible_inventory_path}/inventory.yml ] && cp ${local.ansible_inventory_path}/inventory.yml ${local.ansible_inventory_path}/inventory.yml.bak || true
      ${join("\n", [
        for node in local.all_nodes :
        "ssh-keygen -f ~/.ssh/known_hosts -R ${node.ip} || true"
      ])}
      echo "[master]" > ${local.ansible_inventory_path}/inventory.yml
      ${join("\n", [
        for node in local.master_config :
        "echo 'vm${split(".", node.ip)[3]} ansible_host=${node.ip} ansible_ssh_user=${var.vm_username} ansible_ssh_private_key_file=~/.ssh/id_ed25519_k8s-cluster' >> ${local.ansible_inventory_path}/inventory.yml"
      ])}
      echo "\n[workers]" >> ${local.ansible_inventory_path}/inventory.yml
      ${join("\n", [
        for node in local.workers_config :
        "echo 'vm${split(".", node.ip)[3]} ansible_host=${node.ip} ansible_ssh_user=${var.vm_username} ansible_ssh_private_key_file=~/.ssh/id_ed25519_k8s-cluster' >> ${local.ansible_inventory_path}/inventory.yml"
      ])}
      chmod 644 ${local.ansible_inventory_path}/inventory.yml
    EOT
  }
}
resource "null_resource" "start_all_vms" {
  depends_on = [null_resource.generate_inventory]

  provisioner "local-exec" {
    command = <<EOT
      echo ">>> STEP: Starting all VMs after configuration..."
      ${join("\n", [for node in local.all_nodes : "vmrun -T ws start ${node.path} || echo 'Warning: Failed to start ${node.key}'"])}
      sleep 10
      echo "All VMs started."
    EOT
  }
}