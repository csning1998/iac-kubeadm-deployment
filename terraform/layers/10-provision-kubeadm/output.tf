
output "kubeconfig_content" {
  description = "The kubeconfig content for the cluster."
  value       = module.bootstrapper_ansible_cluster.kubeconfig_content
  sensitive   = true
}

output "k8s_pod_subnet" {
  description = "The CIDR for the Pod network."
  value       = var.kubeadm_cluster_config.pod_subnet
}
