
locals {

  all_nodes_map = { for idx, config in var.harbor_cluster_config.nodes.harbor :
    "harbor-node-${format("%02d", idx)}" => config
  }
  ansible_root_path = abspath("${path.root}/../../../ansible")

  registry_nat_network_gateway       = cidrhost(var.registry_infrastructure.network.nat.cidr, 1)
  registry_nat_network_subnet_prefix = join(".", slice(split(".", split("/", var.registry_infrastructure.network.nat.cidr)[0]), 0, 3))
  ssh_content_registry = flatten([
    for key, node in local.all_nodes_map : {
      nodes = {
        key = key
        ip  = node.ip
      }
      config_name = var.harbor_cluster_config.cluster_name
    }
  ])
}
