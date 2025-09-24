module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm"

  # --- Map Layer's specific variables to the Module's generic inputs ---

  # VM Configuration
  all_nodes_map              = local.all_nodes_map
  libvirt_vm_base_image_path = var.k8s_cluster_vm_base_image_path

  # VM Credentials from Vault
  vm_username         = data.vault_generic_secret.iac_vars.data["vm_username"]
  vm_password         = data.vault_generic_secret.iac_vars.data["vm_password"]
  ssh_public_key_path = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]

  # Libvirt Network & Storage Configuration
  libvirt_storage_pool_name         = var.k8s_cluster_storage_pool_name # Name specific to this K8s cluster
  libvirt_nat_network_cidr          = local.k8s_cluster_nat_network_cidr
  libvirt_nat_network_name          = var.k8s_cluster_nat_network_name
  libvirt_nat_network_gateway       = var.k8s_cluster_nat_network_gateway
  libvirt_nat_network_subnet_prefix = var.k8s_cluster_nat_network_subnet_prefix
  libvirt_hostonly_network_name     = var.k8s_cluster_hostonly_network_name
  libvirt_hostonly_network_cidr     = var.k8s_cluster_hostonly_network_cidr
}

module "ansible" {
  source = "../../modules/12-bootstrapper-ansible"

  ansible_path = local.ansible_path
  vm_status    = module.provisioner_kvm.vm_status
  all_nodes    = module.provisioner_kvm.all_nodes

  vm_username           = data.vault_generic_secret.iac_vars.data["vm_username"]
  ssh_private_key_path  = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  k8s_master_ips        = local.k8s_master_ips
  k8s_ha_virtual_ip     = var.k8s_ha_virtual_ip
  k8s_pod_subnet        = var.k8s_pod_subnet
  k8s_pod_subnet_prefix = var.k8s_cluster_nat_network_subnet_prefix
}
