output "all_nodes" {
  description = "List of all nodes (master and workers)"
  value       = var.all_nodes
}

output "master_config" {
  description = "Configuration for master nodes"
  value = [
    for node in var.all_nodes :
    node if startswith(node.key, "k8s-master")
  ]
}

output "worker_config" {
  description = "Configuration for worker nodes"
  value = [
    for node in var.all_nodes :
    node if startswith(node.key, "k8s-worker")
  ]
}

output "vm_status" {
  description = "The status ID of the VM readiness check resource."
  value       = null_resource.prepare_ssh_access.id
}
