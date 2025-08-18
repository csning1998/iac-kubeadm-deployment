module "vm" {
  source               = "./modules/vm"
  vm_username          = var.vm_username
  vm_password          = var.vm_password
  ssh_private_key_path = var.ssh_private_key_path
  master_ip_list       = var.master_ip_list
  worker_ip_list       = var.worker_ip_list
  master_vcpu          = var.master_vcpu
  master_ram           = var.master_ram
  worker_vcpu          = var.worker_vcpu
  worker_ram           = var.worker_ram
  vms_dir              = local.vms_dir
  vmx_image_path       = local.vmx_image_path
  all_nodes            = local.all_nodes
}

module "ansible" {
  source               = "./modules/ansible"
  vm_username          = var.vm_username
  ssh_private_key_path = var.ssh_private_key_path
  ansible_path         = local.ansible_path
  vault_pass_path      = local.vault_pass_path
  all_nodes            = module.vm.all_nodes
  master_config        = module.vm.master_config
  worker_config        = module.vm.worker_config
  vm_status            = module.vm.vm_status
}
