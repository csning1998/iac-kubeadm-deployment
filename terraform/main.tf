module "vm" {
  source               = "./modules/vm"
  vm_username          = var.vm_username
  ssh_private_key_path = var.ssh_private_key_path
  vms_dir              = local.vms_dir
  vmx_image_path       = local.vmx_image_path
  all_nodes            = local.all_nodes
  nat_gateway            = var.nat_gateway
  nat_subnet_prefix      = var.nat_subnet_prefix
}

module "ansible" {
  source               = "./modules/ansible"
  vm_username          = var.vm_username
  ssh_private_key_path = var.ssh_private_key_path
  ansible_path         = local.ansible_path
  vm_status            = module.vm.vm_status
  all_nodes            = local.all_nodes
  k8s_master_ips       = var.master_ip_list
  k8s_ha_virtual_ip    = var.k8s_ha_virtual_ip
  k8s_pod_subnet       = var.k8s_pod_subnet
  nat_subnet_prefix    = var.nat_subnet_prefix  # Pass this for dynamic interface detection
}
