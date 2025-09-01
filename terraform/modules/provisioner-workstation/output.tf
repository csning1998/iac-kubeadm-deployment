output "all_nodes" {
  description = "List of all nodes (master and workers)"
  value       = var.all_nodes
}

output "vm_status" {
  description = "The status ID of the VM readiness check resource."
  value       = { for key, res in null_resource.configure_nodes : key => res.id }
}
