locals {

  ansible_path = abspath("${path.root}/../../../ansible")

  masters_map = { for idx, config in var.k8s_cluster_nodes.masters :
    "k8s-master-${format("%02d", idx)}" => config
  }
  workers_map = { for idx, config in var.k8s_cluster_nodes.workers :
    "k8s-worker-${format("%02d", idx)}" => config
  }

  all_nodes_map                = merge(local.masters_map, local.workers_map)
  k8s_master_ips               = [for config in var.k8s_cluster_nodes.masters : config.ip]
  k8s_cluster_nat_network_cidr = "${var.k8s_cluster_nat_network_subnet_prefix}.0/24"
}
