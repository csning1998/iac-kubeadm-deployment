# Input & Trigger Configuration

variable "redis_nodes" {
  description = "A map of Redis nodes to be configured."
  type = map(object({
    ip   = string
    vcpu = number
    ram  = number
  }))
}

# Ansible Execution Environment

variable "vm_credentials" {
  description = "Credentials for Ansible to access the target VMs."
  type = object({
    username             = string
    ssh_private_key_path = string
  })
}

variable "redis_credentials" {
  description = "Credentials for Ansible to access the target Databases."
  type = object({
    requirepass = string
    masterauth  = string
  })
  sensitive = true
}

# Ansible Playbook Configuration

variable "ansible_config" {
  description = "Configurations for the Ansible execution environment and playbook."
  type = object({
    root_path       = string
    ssh_config_path = string
    extra_vars = object({
      redis_allowed_subnet = string
    })
  })
}

variable "status_trigger" {
  description = "A trigger value that changes when the underlying VMs are provisioned."
  type        = any
}
