variable "vm_username" {
  description = "Username for SSH access to the VMs"
  type        = string
  sensitive   = false
}

variable "ansible_path" {
  description = "Path to Ansible directory"
  type        = string
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to the SSH private key for Ansible."
}

variable "vault_pass_path" {
  description = "Path to Ansible vault password file"
  type        = string
}

variable "vm_status" {
  description = "Status of VM startup"
  type        = string
}

variable "all_nodes" {
  description = "List of all nodes (master and workers)"
  type = list(object({
    key  = string
    ip   = string
    vcpu = number
    ram  = number
    path = string
  }))
}
