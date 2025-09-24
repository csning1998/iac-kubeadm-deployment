locals {

  ansible_root_path = abspath("${path.root}/../../../ansible")

  masters_map = { for idx, config in var.k8s_cluster_config.nodes.masters :
    "k8s-master-${format("%02d", idx)}" => config
  }
  workers_map = { for idx, config in var.k8s_cluster_config.nodes.workers :
    "k8s-worker-${format("%02d", idx)}" => config
  }

  all_nodes_map  = merge(local.masters_map, local.workers_map)
  k8s_master_ips = [for config in var.k8s_cluster_config.nodes.masters : config.ip]

  k8s_cluster_nat_network_gateway       = cidrhost(var.cluster_infrastructure.network.nat.cidr, 2)
  k8s_cluster_nat_network_subnet_prefix = join(".", slice(split(".", split("/", var.cluster_infrastructure.network.nat.cidr)[0]), 0, 3))
}
