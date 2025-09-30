
output "ssh_access_ready_trigger" {
  description = "A trigger that can be used to signal the completion of the SSH preparation steps."
  value       = null_resource.prepare_ssh_access.triggers
}
