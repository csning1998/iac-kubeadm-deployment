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
    root_path     = string
    registry_host = string
    extra_vars = object({
      k8s_master_ips        = list(string)
      k8s_ha_virtual_ip     = string
      k8s_pod_subnet        = string
      k8s_nat_subnet_prefix = string
    })
  })
}
