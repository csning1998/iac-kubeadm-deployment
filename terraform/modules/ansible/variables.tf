variable "vm_username" {
  description = "Username for SSH access to the VMs"
  type        = string
  sensitive   = false
}

variable "ansible_path" {
  description = "Path to Ansible directory"
  type        = string
}

variable "vault_pass_path" {
  description = "Path to Ansible vault password file"
  type        = string
}

variable "all_nodes" {
  description = "List of all nodes (master and workers)"
  type        = list(object({
    key  = string
    ip   = string
    vcpu = number
    ram  = number
    path = string
  }))
}

variable "master_config" {
  description = "Configuration for master node(s)"
  type        = list(object({
    key  = string
    ip   = string
    vcpu = number
    ram  = number
    path = string
  }))
}

variable "worker_config" {
  description = "Configuration for worker nodes"
  type        = list(object({
    key  = string
    ip   = string
    vcpu = number
    ram  = number
    path = string
  }))
}


variable "vm_status" {
  description = "Status of VM startup"
  type        = string
}