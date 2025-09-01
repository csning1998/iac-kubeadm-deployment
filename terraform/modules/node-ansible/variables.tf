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

# variable "vault_pass_path" {
#   description = "Path to Ansible vault password file"
#   type        = string
# }

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

# Variables for Kubernetes network configuration

variable "k8s_master_ips" {
  description = "List of IP addresses for the master nodes."
  type        = list(string)
}

variable "k8s_ha_virtual_ip" {
  description = "The virtual IP for the HA cluster."
  type        = string
}

variable "k8s_pod_subnet" {
  description = "The CIDR for the Pod network."
  type        = string
}

variable "nat_subnet_prefix" {
  description = "The subnet prefix for the NAT network, used for interface discovery."
  type        = string
}