# output "ansible_playbook_stdout" {
#   description = "Ansible Playbook CLI stdout output for each node"
#   value = {
#     for key, instance in ansible_playbook.provision_k8s : key => instance.ansible_playbook_stdout
#   }
# }

# output "ansible_playbook_stderr" {
#   description = "Ansible Playbook CLI stderr output for each node"
#   value = {
#     for key, instance in ansible_playbook.provision_k8s : key => instance.ansible_playbook_stderr
#   }
# }

output "ansible_log" {
  description = "Path to Ansible execution log"
  value       = "${var.ansible_config.root_path}/logs/ansible-latest.log"
}
