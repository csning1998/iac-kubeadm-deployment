variable "master_ip_list" {
  description = "List of IP addresses for the master nodes."
  type        = list(string)
}

variable "worker_ip_list" {
  description = "List of IP addresses for the worker nodes."
  type        = list(string)
}

variable "master_vcpu" { type = number }
variable "master_ram" { type = number }
variable "worker_vcpu" { type = number }
variable "worker_ram" { type = number }

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

variable "qemu_base_image_path" {
  description = "Path to the Packer-built qcow2 base image"
  type        = string
}

variable "libvirt_pool" {
  description = "The name of the libvirt storage pool to use"
  type        = string
  default     = "default"
}

variable "nat_gateway" {
  description = "Gateway for the NAT network"
  type        = string
}

variable "nat_subnet_prefix" {
  description = "The first three octets of the NAT subnet (e.g., '172.16.86')."
  type        = string
}

variable "nat_network_name" {
  description = "Name for the NAT libvirt network"
  type        = string
  default     = "iac-kubeadm-nat-net"
}

variable "nat_network_cidr" {
  description = "CIDR for the NAT network"
  type        = string
}

variable "hostonly_network_name" {
  description = "Name for the Host-only libvirt network"
  type        = string
  default     = "iac-kubeadm-hostonly-net"
}

variable "hostonly_network_cidr" {
  description = "CIDR for the Host-only network"
  type        = string
}
