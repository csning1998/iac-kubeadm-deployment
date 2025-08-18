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

variable "vm_password" {
  description = "Password for SSH access to the VMs"
  type        = string
  sensitive   = true
}

variable "master_ip_list" {
  description = "IP address list for the Kubernetes master node"
  type        = list(string)
}

variable "worker_ip_list" {
  description = "IP address list for the Kubernetes worker nodes"
  type        = list(string)
}

variable "master_vcpu" {
  description = "Number of vCPUs for the Kubernetes master node"
  type        = number
}

variable "master_ram" {
  description = "Amount of RAM (in MB) for the Kubernetes master node"
  type        = number
}

variable "worker_vcpu" {
  description = "Number of vCPUs for each Kubernetes worker node"
  type        = number
}

variable "worker_ram" {
  description = "Amount of RAM (in MB) for each Kubernetes worker node"
  type        = number
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
