
/** 
 * Virtual Machine Configuration
 * Variables defining the specifications and credentials for the VMs.
*/

variable "all_nodes_map" {
  description = "Definitions of all nodes passed in from the root module"
  type = map(object({
    ip   = string
    vcpu = number
    ram  = number
  }))
}

variable "vm_username" {
  description = "Username for SSH access to the VMs"
  type        = string
  sensitive   = false
}

variable "vm_password" {
  description = "Password for SSH access to the VMs"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for the automation user"
  type        = string
}

variable "libvirt_vm_base_image_path" {
  description = "Path to the Packer-built qcow2 base image"
  type        = string
}

/** 
 * Libvirt Network & Storage Configuration
 * Variables defining the names and CIDRs for Libvirt-managed resources.
 * These MUST be explicitly defined by the calling layer to avoid conflicts.
*/

variable "libvirt_nat_network_gateway" {
  description = "Gateway for the NAT network"
  type        = string
}

variable "libvirt_nat_network_subnet_prefix" {
  description = "The first three octets of the NAT subnet (e.g., '172.16.86')."
  type        = string
}

variable "libvirt_nat_network_name" {
  description = "Name for the NAT libvirt network"
  type        = string
}

variable "libvirt_nat_network_cidr" {
  description = "CIDR for the NAT network"
  type        = string
}

variable "libvirt_hostonly_network_name" {
  description = "Name for the Host-only libvirt network"
  type        = string
}

variable "libvirt_hostonly_network_cidr" {
  description = "CIDR for the Host-only network"
  type        = string
}

variable "libvirt_storage_pool_name" {
  description = "The unique name for the Libvirt storage pool."
  type        = string
}
