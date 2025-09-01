
# --- Provisioner Selection ---
module "provisioner_kvm" {
  count = var.provisioner_type == "kvm" ? 1 : 0

  source = "./modules/provisioner-kvm"

  all_nodes             = local.all_nodes
  master_config         = local.master_config
  worker_config         = local.workers_config
  qemu_base_image_path  = abspath(var.qemu_base_image_path)
  vm_username           = var.vm_username
  vm_password           = var.vm_password
  ssh_public_key_path   = var.ssh_public_key_path
  nat_network_cidr      = "${var.nat_subnet_prefix}.0/24"
  nat_gateway           = var.nat_gateway
  nat_subnet_prefix     = var.nat_subnet_prefix
  hostonly_network_cidr = var.kvm_hostonly_cidr
  hostonly_network_name = var.hostonly_network_name
}

module "provisioner_workstation" {
  count = var.provisioner_type == "workstation" ? 1 : 0

  source = "./modules/provisioner-workstation"

  vm_username          = var.vm_username
  ssh_private_key_path = var.ssh_private_key_path
  vms_dir              = local.vms_dir
  vmx_image_path       = local.vmx_image_path
  all_nodes            = local.all_nodes
  nat_gateway          = var.nat_gateway
  nat_subnet_prefix    = var.nat_subnet_prefix
}

# --- Merge Outputs and Run Ansible ---
locals {
  provisioner_output = var.provisioner_type == "kvm" ? module.provisioner_kvm[0] : module.provisioner_workstation[0]
}

module "ansible" {
  source = "./modules/node-ansible"

  vm_status = local.provisioner_output.vm_status

  all_nodes            = local.provisioner_output.all_nodes
  vm_username          = var.vm_username
  ssh_private_key_path = var.ssh_private_key_path
  ansible_path         = local.ansible_path
  k8s_master_ips       = var.master_ip_list
  k8s_ha_virtual_ip    = var.k8s_ha_virtual_ip
  k8s_pod_subnet       = var.k8s_pod_subnet
  nat_subnet_prefix    = var.nat_subnet_prefix
}
