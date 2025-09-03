module "provisioner_kvm" {
  source = "./modules/provisioner-kvm"

  all_nodes_map = local.all_nodes_map

  qemu_base_image_path  = var.qemu_base_image_path
  vm_username           = var.vm_username
  vm_password           = var.vm_password
  ssh_public_key_path   = var.ssh_public_key_path
  nat_gateway           = var.nat_gateway
  nat_subnet_prefix     = var.nat_subnet_prefix
  nat_network_cidr      = local.nat_network_cidr
  hostonly_network_cidr = var.kvm_hostonly_cidr
}

module "ansible" {
  source = "./modules/node-ansible"

  ansible_path = local.ansible_path
  vm_status    = module.provisioner_kvm.vm_status
  all_nodes    = module.provisioner_kvm.all_nodes

  vm_username          = var.vm_username
  ssh_private_key_path = var.ssh_private_key_path
  k8s_master_ips       = local.k8s_master_ips
  k8s_ha_virtual_ip    = var.k8s_ha_virtual_ip
  k8s_pod_subnet       = var.k8s_pod_subnet
  nat_subnet_prefix    = var.nat_subnet_prefix
}
