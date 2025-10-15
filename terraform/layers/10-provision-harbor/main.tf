module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm"

  # --- Map Layer's specific variables to the Module's generic inputs ---

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.harbor_cluster_config.base_image_path
  }

  # VM Credentials from Vault
  credentials = {
    username            = data.vault_generic_secret.iac_vars.data["vm_username"]
    password            = data.vault_generic_secret.iac_vars.data["vm_password"]
    ssh_public_key_path = data.vault_generic_secret.iac_vars.data["ssh_public_key_path"]
  }

  # Libvirt Network & Storage Configuration
  libvirt_infrastructure = {
    network = {
      nat = {
        name          = var.harbor_infrastructure.network.nat.name
        cidr          = var.harbor_infrastructure.network.nat.cidr
        gateway       = local.harbor_nat_network_gateway
        subnet_prefix = local.harbor_nat_network_subnet_prefix
        bridge_name   = var.harbor_infrastructure.network.nat.bridge_name
      }
      hostonly = {
        name        = var.harbor_infrastructure.network.hostonly.name
        cidr        = var.harbor_infrastructure.network.hostonly.cidr
        bridge_name = var.harbor_infrastructure.network.hostonly.bridge_name
      }
    }
    storage_pool_name = var.harbor_infrastructure.storage_pool_name
  }
}

module "ssh_config_manager_harbor" {
  source = "../../modules/81-ssh-config-manager"

  config_name = var.harbor_cluster_config.cluster_name
  nodes       = module.provisioner_kvm.all_nodes_map
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
  status_trigger = module.provisioner_kvm.vm_status_trigger
}

module "bootstrapper_ansible_cluster" {
  source = "../../modules/13-bootstrapper-ansible-harbor"

  ansible_config = {
    root_path = local.ansible_root_path
  }

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  inventory = {
    nodes          = module.provisioner_kvm.all_nodes_map
    status_trigger = module.ssh_config_manager_harbor.ssh_access_ready_trigger
  }
}
