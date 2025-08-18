module "vm" {
  source               = "./modules/vm"
  vm_username          = var.vm_username
  ssh_private_key_path = var.ssh_private_key_path
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
  vm_status            = module.vm.vm_status
  all_nodes            = local.all_nodes
}
