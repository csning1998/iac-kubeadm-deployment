module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm"

  all_nodes_map = local.all_nodes_map

  qemu_base_image_path  = var.qemu_base_image_path
  vm_username           = data.vault_generic_secret.iac_vars.data["vm_username"]
  vm_password           = data.vault_generic_secret.iac_vars.data["vm_password"]
  ssh_public_key_path   = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
  nat_gateway           = var.nat_gateway
  nat_subnet_prefix     = var.nat_subnet_prefix
  nat_network_cidr      = local.nat_network_cidr
  hostonly_network_cidr = var.kvm_hostonly_cidr
}

module "ansible" {
  source = "../../modules/12-bootstrapper-ansible"

  ansible_path = local.ansible_path
  vm_status    = module.provisioner_kvm.vm_status
  all_nodes    = module.provisioner_kvm.all_nodes

  vm_username          = data.vault_generic_secret.iac_vars.data["vm_username"]
  ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  k8s_master_ips       = local.k8s_master_ips
  k8s_ha_virtual_ip    = var.k8s_ha_virtual_ip
  k8s_pod_subnet       = var.k8s_pod_subnet
  nat_subnet_prefix    = var.nat_subnet_prefix
}
