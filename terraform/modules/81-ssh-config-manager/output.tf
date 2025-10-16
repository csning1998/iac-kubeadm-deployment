
output "ssh_access_ready_trigger" {
  description = "A trigger that can be used to signal the completion of the SSH preparation steps."
  value       = null_resource.prepare_ssh_access.triggers
}

output "ssh_config_file_path" {
  description = "The absolute path to the generated SSH config file."
  value       = local_file.ssh_config.filename
}
