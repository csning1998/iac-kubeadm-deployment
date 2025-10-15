locals {

  ansible_root_path = abspath("${path.root}/../../../ansible")

  masters_map = { for idx, config in var.kubeadm_cluster_config.nodes.masters :
    "kubeadm-master-${format("%02d", idx)}" => config
  }
  workers_map = { for idx, config in var.kubeadm_cluster_config.nodes.workers :
    "kubeadm-worker-${format("%02d", idx)}" => config
  }

  all_nodes_map  = merge(local.masters_map, local.workers_map)
  k8s_master_ips = [for config in var.kubeadm_cluster_config.nodes.masters : config.ip]

  k8s_cluster_nat_network_gateway       = cidrhost(var.cluster_infrastructure.network.nat.cidr, 1)
  k8s_cluster_nat_network_subnet_prefix = join(".", slice(split(".", split("/", var.cluster_infrastructure.network.nat.cidr)[0]), 0, 3))

  # Flatten the all_nodes_map into the list format expected by the ssh-config-manager module.
  ssh_content_cluster = flatten([
    for key, node in local.all_nodes_map : {
      nodes = {
        key = key
        ip  = node.ip
      }
      config_name = var.kubeadm_cluster_config.cluster_name
    }
  ])
}
