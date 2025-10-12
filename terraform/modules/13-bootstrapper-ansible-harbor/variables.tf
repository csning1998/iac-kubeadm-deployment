# Input & Trigger Configuration

variable "inventory" {
  description = "The inventory of all nodes to be managed by Ansible."
  type = object({
    nodes = list(object({
      key  = string
      ip   = string
      vcpu = number
      ram  = number
      path = string
    }))
    status_trigger = any
  })
}

# Ansible Execution Environment

variable "vm_credentials" {
  description = "Credentials for Ansible to access the target VMs."
  type = object({
    username             = string
    ssh_private_key_path = string
  })
}

# Ansible Playbook Configuration

variable "ansible_config" {
  description = "Configurations for the Ansible execution environment and playbook."
  type = object({
    root_path = string
  })
}
