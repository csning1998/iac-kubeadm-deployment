variable "vm_username" {
  description = "Username for SSH access to the VMs"
  type        = string
  sensitive   = false
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key for connecting to the VMs."
  type        = string
  sensitive   = true
}

variable "vms_dir" {
  description = "Directory for VM storage"
  type        = string
}

variable "vmx_image_path" {
  description = "Path to the VMware VMX image"
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

variable "nat_gateway" {
  description = "The gateway IP address for the NAT network (vmnet8)."
  type        = string
}

variable "nat_subnet_prefix" {
  description = "The first three octets of the NAT subnet (e.g., '172.16.86')."
  type        = string
}
