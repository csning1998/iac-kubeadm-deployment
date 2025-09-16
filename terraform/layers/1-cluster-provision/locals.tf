locals {

  provisioner_output = module.provisioner_kvm
  ansible_path       = abspath("${path.root}/../../../ansible")

  masters_map = { for idx, config in var.node_configs.masters :
    "k8s-master-${format("%02d", idx)}" => config
  }
  workers_map = { for idx, config in var.node_configs.workers :
    "k8s-worker-${format("%02d", idx)}" => config
  }

  all_nodes_map  = merge(local.masters_map, local.workers_map)
  k8s_master_ips = [for config in var.node_configs.masters : config.ip]

  nat_network_cidr = "${var.nat_subnet_prefix}.0/24"
}
