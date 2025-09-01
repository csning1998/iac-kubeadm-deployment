# Show the outputs of Cluster Nodes

output "master_details" {
  description = "Connection details and IP address for the Kubernetes master node"
  sensitive   = false
  value = {
    for node in local.provisioner_output.all_nodes : node.key => {
      ip_address  = node.ip
      ssh_command = "ssh ${var.vm_username}@${node.ip}"
    } if substr(node.key, 0, 10) == "k8s-master"
  }
}

output "workers_details" {
  description = "Connection details and IP addresses for the Kubernetes worker nodes"
  sensitive   = false
  value = {
    for node in local.provisioner_output.all_nodes : node.key => {
      ip_address  = node.ip
      ssh_command = "ssh ${var.vm_username}@${node.ip}"
    } if substr(node.key, 0, 10) == "k8s-worker"
  }
}

output "ansible_log_path" {
  description = "Path to the latest Ansible execution log"
  value       = module.ansible.ansible_log
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
