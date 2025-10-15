# Input & Trigger Configuration

variable "postgres_nodes" {
  description = "A map of PostgreSQL nodes to be configured."
  type = map(object({
    ip   = string
    vcpu = number
    ram  = number
  }))
}

variable "etcd_nodes" {
  description = "A map of etcd nodes to be configured."
  type = map(object({
    ip   = string
    vcpu = number
    ram  = number
  }))
}

variable "haproxy_nodes" {
  description = "A map of HAProxy nodes to be configured."
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

variable "db_credentials" {
  description = "Credentials for Ansible to access the target Databases."
  type = object({
    superuser_password   = string
    replication_password = string
  })
}

# Ansible Playbook Configuration

variable "ansible_config" {
  description = "Configurations for the Ansible execution environment and playbook."
  type = object({
    root_path = string
    extra_vars = object({
      postgres_allowed_subnet = string
    })
  })
}

variable "status_trigger" {
  description = "A trigger value that changes when the underlying VMs are provisioned."
  type        = any
}
