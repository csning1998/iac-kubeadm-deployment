variable "vm_username" {
  description = "Username for SSH access to the VMs"
  type        = string
  sensitive   = true
}

variable "vm_password" {
  description = "Password for SSH access to the VMs"
  type        = string
  sensitive   = true
}