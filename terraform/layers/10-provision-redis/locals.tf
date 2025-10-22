
locals {

  redis_nodes_map = { for idx, config in var.redis_cluster_config.nodes.redis :
    "redis-node-${format("%02d", idx)}" => config
  }

  all_nodes_map = merge(
    local.redis_nodes_map,
  )

  ansible_root_path = abspath("${path.root}/../../../ansible")

  redis_nat_network_gateway       = cidrhost(var.redis_infrastructure.network.nat.cidr, 1)
  redis_nat_network_subnet_prefix = join(".", slice(split(".", split("/", var.redis_infrastructure.network.nat.cidr)[0]), 0, 3))
}
