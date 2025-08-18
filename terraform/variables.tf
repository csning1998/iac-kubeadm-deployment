### Variables for SSH login

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

variable "ssh_private_key_path" {
  type        = string
  description = "Path to the SSH private key for connecting to the VMs."
}

### Variables to Configure IP Addresses for Master Node(s) and Worker Nodes. 

variable "master_ip_list" {
  description = "IP address list for the Kubernetes master node"
  type        = list(string)
  default     = ["172.16.134.200"] # Add IP for setting up High Abilities
}

variable "worker_ip_list" {
  description = "IP address list for the Kubernetes worker nodes"
  type        = list(string)
  default     = ["172.16.134.210", "172.16.134.211", "172.16.134.212"]
}

### Configure Resources for the Infrastructure 

variable "master_vcpu" {
  description = "Number of vCPUs for the Kubernetes master node"
  type        = number
  default     = 4
}

variable "master_ram" {
  description = "Amount of RAM (in MB) for the Kubernetes master node"
  type        = number
  default     = 6144
}

variable "worker_vcpu" {
  description = "Number of vCPUs for each Kubernetes worker node"
  type        = number
  default     = 6
}

variable "worker_ram" {
  description = "Amount of RAM (in MB) for each Kubernetes worker node"
  type        = number
  default     = 12288
}
