output "ansible_playbook_stdout" {
  description = "Ansible Playbook CLI stdout output for each node"
  value = {
    for key, instance in ansible_playbook.setup_k8s : key => instance.ansible_playbook_stdout
  }
}

output "ansible_playbook_stderr" {
  description = "Ansible Playbook CLI stderr output for each node"
  value = {
    for key, instance in ansible_playbook.setup_k8s : key => instance.ansible_playbook_stderr
  }
}