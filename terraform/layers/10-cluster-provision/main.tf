module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm"

  # --- Map Layer's specific variables to the Module's generic inputs ---

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.k8s_cluster_config.base_image_path
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
        name          = var.cluster_infrastructure.network.nat.name
        cidr          = var.cluster_infrastructure.network.nat.cidr
        gateway       = local.k8s_cluster_nat_network_gateway
        subnet_prefix = local.k8s_cluster_nat_network_subnet_prefix
        bridge_name   = var.cluster_infrastructure.network.nat.bridge_name
      }
      hostonly = {
        name        = var.cluster_infrastructure.network.hostonly.name
        cidr        = var.cluster_infrastructure.network.hostonly.cidr
        bridge_name = var.cluster_infrastructure.network.hostonly.bridge_name
      }
    }
    storage_pool_name = var.cluster_infrastructure.storage_pool_name
  }
}

module "ssh_config_manager" {
  source = "../../modules/81-ssh-config-manager"

  config_name = var.k8s_cluster_config.cluster_name
  nodes       = module.provisioner_kvm.all_nodes_map
  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }
  status_trigger = module.provisioner_kvm.vm_status_trigger
}

module "bootstrapper_ansible" {
  source = "../../modules/12-bootstrapper-ansible"

  ansible_config = {
    root_path = local.ansible_root_path
    extra_vars = {
      k8s_master_ips        = local.k8s_master_ips
      k8s_ha_virtual_ip     = var.k8s_cluster_config.ha_virtual_ip
      k8s_pod_subnet        = var.k8s_cluster_config.pod_subnet
      k8s_nat_subnet_prefix = local.k8s_cluster_nat_network_subnet_prefix
    }
  }

  vm_credentials = {
    username             = data.vault_generic_secret.iac_vars.data["vm_username"]
    ssh_private_key_path = data.vault_generic_secret.iac_vars.data["ssh_private_key_path"]
  }

  inventory = {
    nodes          = module.provisioner_kvm.all_nodes_map
    status_trigger = module.ssh_config_manager.ssh_access_ready_trigger
  }
}
