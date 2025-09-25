module "provisioner_kvm" {
  source = "../../modules/11-provisioner-kvm"

  # --- Map Layer's specific variables to the Module's generic inputs ---

  # VM Configuration
  vm_config = {
    all_nodes_map   = local.all_nodes_map
    base_image_path = var.registry_config.base_image_path
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
        name          = var.registry_infrastructure.network.nat.name
        cidr          = var.registry_infrastructure.network.nat.cidr
        gateway       = local.registry_nat_network_gateway
        subnet_prefix = local.registry_nat_network_subnet_prefix
        bridge_name   = var.registry_infrastructure.network.nat.bridge_name

      }
      hostonly = {
        name        = var.registry_infrastructure.network.hostonly.name
        cidr        = var.registry_infrastructure.network.hostonly.cidr
        bridge_name = var.registry_infrastructure.network.hostonly.bridge_name
      }
    }
    storage_pool_name = var.registry_infrastructure.storage_pool_name
  }
}
