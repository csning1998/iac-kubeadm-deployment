output "ansible_log_path" {
  description = "Path to the latest Ansible execution log"
  value       = module.bootstrapper_ansible.ansible_log
}

output "kubeconfig_content" {
  description = "The kubeconfig content for the cluster."
  value       = module.bootstrapper_ansible.kubeconfig_content
  sensitive   = true
}

output "k8s_pod_subnet" {
  description = "The CIDR for the Pod network."
  value       = var.k8s_cluster_config.pod_subnet
}
