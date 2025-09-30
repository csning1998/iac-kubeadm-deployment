
locals {

  all_nodes_map = { for idx, config in var.registry_config.nodes.registry :
    "registry-server-${format("%02d", idx)}" => config
  }

  registry_nat_network_gateway       = cidrhost(var.registry_infrastructure.network.nat.cidr, 2)
  registry_nat_network_subnet_prefix = join(".", slice(split(".", split("/", var.registry_infrastructure.network.nat.cidr)[0]), 0, 3))
  ssh_content_registry = flatten([
    for key, node in local.all_nodes_map : {
      nodes = {
        key = key
        ip  = node.ip
      }
      config_name = var.registry_config.registry_name
    }
  ])
}
