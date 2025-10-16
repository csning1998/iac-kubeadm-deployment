module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm"

  # --- Map Layer's specific variables to the Module's generic inputs ---

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.postgres_cluster_config.base_image_path
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
        name          = var.postgres_infrastructure.network.nat.name
        cidr          = var.postgres_infrastructure.network.nat.cidr
        gateway       = local.postgres_nat_network_gateway
        subnet_prefix = local.postgres_nat_network_subnet_prefix
        bridge_name   = var.postgres_infrastructure.network.nat.bridge_name
      }
      hostonly = {
        name        = var.postgres_infrastructure.network.hostonly.name
        cidr        = var.postgres_infrastructure.network.hostonly.cidr
        bridge_name = var.postgres_infrastructure.network.hostonly.bridge_name
      }
    }
    storage_pool_name = var.postgres_infrastructure.storage_pool_name
  }
}

module "ssh_config_manager_postgres" {
  source = "../../modules/81-ssh-config-manager"

  config_name = var.postgres_cluster_config.cluster_name
  nodes       = module.provisioner_kvm.all_nodes_map
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
  status_trigger = module.provisioner_kvm.vm_status_trigger
}

module "bootstrapper_ansible_cluster" {
  source = "../../modules/14-bootstrapper-ansible-postgres"

  ansible_config = {
    root_path       = local.ansible_root_path
    ssh_config_path = module.ssh_config_manager_postgres.ssh_config_file_path
    extra_vars = {
      postgres_allowed_subnet = var.postgres_infrastructure.postgres_allowed_subnet
    }
  }

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  db_credentials = {
    superuser_password   = data.vault_generic_secret.db_vars.data["pg_superuser_password"]
    replication_password = data.vault_generic_secret.db_vars.data["pg_replication_password"]
  }

  postgres_nodes = local.postgres_nodes_map
  etcd_nodes     = local.etcd_nodes_map
  haproxy_nodes  = local.haproxy_nodes_map

  status_trigger = module.ssh_config_manager_postgres.ssh_access_ready_trigger
}
