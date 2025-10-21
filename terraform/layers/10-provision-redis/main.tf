module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm"

  # --- Map Layer's specific variables to the Module's generic inputs ---

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.redis_cluster_config.base_image_path
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
        name          = var.redis_infrastructure.network.nat.name
        cidr          = var.redis_infrastructure.network.nat.cidr
        gateway       = local.redis_nat_network_gateway
        subnet_prefix = local.redis_nat_network_subnet_prefix
        bridge_name   = var.redis_infrastructure.network.nat.bridge_name
      }
      hostonly = {
        name        = var.redis_infrastructure.network.hostonly.name
        cidr        = var.redis_infrastructure.network.hostonly.cidr
        bridge_name = var.redis_infrastructure.network.hostonly.bridge_name
      }
    }
    storage_pool_name = var.redis_infrastructure.storage_pool_name
  }
}

module "ssh_config_manager_redis" {
  source = "../../modules/81-ssh-config-manager"

  config_name = var.redis_cluster_config.cluster_name
  nodes       = module.provisioner_kvm.all_nodes_map
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
  status_trigger = module.provisioner_kvm.vm_status_trigger
}

module "bootstrapper_ansible_cluster" {
  source = "../../modules/15-bootstrapper-ansible-redis"

  ansible_config = {
    root_path       = local.ansible_root_path
    ssh_config_path = module.ssh_config_manager_redis.ssh_config_file_path
    extra_vars = {
      redis_allowed_subnet = var.redis_infrastructure.redis_allowed_subnet
    }
  }

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  redis_credentials = {
    requirepass = data.vault_generic_secret.db_vars.data["redis_requirepass"]
    masterauth  = data.vault_generic_secret.db_vars.data["redis_masterauth"]
  }

  redis_nodes    = local.redis_nodes_map
  status_trigger = module.ssh_config_manager_redis.ssh_access_ready_trigger
}
