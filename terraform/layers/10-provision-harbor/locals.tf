
locals {

  all_nodes_map = { for idx, config in var.harbor_cluster_config.nodes.harbor :
    "harbor-node-${format("%02d", idx)}" => config
  }
  ansible_root_path = abspath("${path.root}/../../../ansible")

  harbor_nat_network_gateway       = cidrhost(var.harbor_infrastructure.network.nat.cidr, 1)
  harbor_nat_network_subnet_prefix = join(".", slice(split(".", split("/", var.harbor_infrastructure.network.nat.cidr)[0]), 0, 3))
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
