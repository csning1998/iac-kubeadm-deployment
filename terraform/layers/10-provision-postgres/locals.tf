
locals {

  postgres_nodes_map = { for idx, config in var.postgres_cluster_config.nodes.postgres :
    "postgres-node-${format("%02d", idx)}" => config
  }

  etcd_nodes_map = { for idx, config in var.postgres_cluster_config.nodes.etcd :
    "etcd-node-${format("%02d", idx)}" => config
  }

  haproxy_nodes_map = { for idx, config in var.postgres_cluster_config.nodes.haproxy :
    "haproxy-node-${format("%02d", idx)}" => config
  }

  all_nodes_map = merge(
    local.postgres_nodes_map,
    local.etcd_nodes_map,
    local.haproxy_nodes_map
  )


  ansible_root_path = abspath("${path.root}/../../../ansible")

  postgres_nat_network_gateway       = cidrhost(var.postgres_infrastructure.network.nat.cidr, 1)
  postgres_nat_network_subnet_prefix = join(".", slice(split(".", split("/", var.postgres_infrastructure.network.nat.cidr)[0]), 0, 3))
}
