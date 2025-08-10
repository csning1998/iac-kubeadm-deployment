output "master_details" {
  description = "Connection details and IP address for the Kubernetes master node"
  sensitive   = false
  value = {
    for node in local.master_config : node.key => {
      ip_address  = node.ip
      ssh_command = "ssh ${var.vm_username}@${node.ip}"
    }
  }
}

output "workers_details" {
  description = "Connection details and IP addresses for the Kubernetes worker nodes"
  sensitive   = false
  value = {
    for node in local.workers_config : node.key => {
      ip_address  = node.ip
      ssh_command = "ssh ${var.vm_username}@${node.ip}"
    }
  }
}