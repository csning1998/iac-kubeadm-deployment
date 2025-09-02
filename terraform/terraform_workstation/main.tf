locals {
  provisioner_output = module.provisioner_workstation
  vms_dir            = "${path.root}/vms"
  vmx_image_path     = abspath("${path.root}/../../packer/output/ubuntu-server-workstation/ubuntu-server-k8s-based-workstation.vmx")
  ansible_path       = abspath("${path.root}/../../ansible/")
}

module "provisioner_workstation" {
  source = "../modules/provisioner-workstation"

  vms_dir              = local.vms_dir
  vmx_image_path       = local.vmx_image_path
  master_ip_list       = var.master_ip_list
  worker_ip_list       = var.worker_ip_list
  master_vcpu          = var.master_vcpu
  master_ram           = var.master_ram
  worker_vcpu          = var.worker_vcpu
  worker_ram           = var.worker_ram
  vm_username          = var.vm_username
  ssh_private_key_path = var.ssh_private_key_path
  nat_gateway          = var.nat_gateway
  nat_subnet_prefix    = var.nat_subnet_prefix
}

module "ansible" {
  source = "../modules/node-ansible"

  ansible_path         = local.ansible_path
  vm_status            = module.provisioner_workstation.vm_status
  all_nodes            = module.provisioner_workstation.all_nodes
  vm_username          = var.vm_username
  ssh_private_key_path = var.ssh_private_key_path
  k8s_master_ips       = var.master_ip_list
  k8s_ha_virtual_ip    = var.k8s_ha_virtual_ip
  k8s_pod_subnet       = var.k8s_pod_subnet
  nat_subnet_prefix    = var.nat_subnet_prefix
}
