locals {
  provisioner_output = module.provisioner_kvm
  ansible_path       = abspath("${path.root}/../ansible/")
}

module "provisioner_kvm" {
  source = "./modules/provisioner-kvm"

  master_ip_list        = var.master_ip_list
  worker_ip_list        = var.worker_ip_list
  master_vcpu           = var.master_vcpu
  master_ram            = var.master_ram
  worker_vcpu           = var.worker_vcpu
  worker_ram            = var.worker_ram
  qemu_base_image_path  = var.qemu_base_image_path
  vm_username           = var.vm_username
  vm_password           = var.vm_password
  ssh_public_key_path   = var.ssh_public_key_path
  nat_network_cidr      = "${var.nat_subnet_prefix}.0/24"
  nat_gateway           = var.nat_gateway
  nat_subnet_prefix     = var.nat_subnet_prefix
  hostonly_network_cidr = var.kvm_hostonly_cidr
  hostonly_network_name = var.hostonly_network_name
}

module "ansible" {
  source = "./modules/node-ansible"

  ansible_path = local.ansible_path

  vm_status = module.provisioner_kvm.vm_status
  all_nodes = module.provisioner_kvm.all_nodes

  vm_username          = var.vm_username
  ssh_private_key_path = var.ssh_private_key_path
  k8s_master_ips       = var.master_ip_list
  k8s_ha_virtual_ip    = var.k8s_ha_virtual_ip
  k8s_pod_subnet       = var.k8s_pod_subnet
  nat_subnet_prefix    = var.nat_subnet_prefix
}
