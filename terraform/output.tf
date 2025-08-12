# Show the outputs of Cluster Nodes

output "master_details" {
  description = "Connection details and IP address for the Kubernetes master node"
  sensitive   = false
  value = {
    for node in module.vm.master_config : node.key => {
      ip_address  = node.ip
      ssh_command = "ssh ${var.vm_username}@${node.ip}"
    }
  }
}

output "workers_details" {
  description = "Connection details and IP addresses for the Kubernetes worker nodes"
  sensitive   = false
  value = {
    for node in module.vm.worker_config : node.key => {
      ip_address  = node.ip
      ssh_command = "ssh ${var.vm_username}@${node.ip}"
    }
  }
}

# Quoting the output of ansible modules

# output "ansible_playbook_stdout" {
#   description = "Ansible Playbook CLI stdout output"
#   value       = module.ansible.ansible_playbook_stdout
# }

# output "ansible_playbook_stderr" {
#   description = "Ansible Playbook CLI stderr output"
#   value       = module.ansible.ansible_playbook_stderr
# }