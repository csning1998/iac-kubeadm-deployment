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

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the SSH public key for connecting to the VMs."
}

variable "ssh_private_key_path" {
  type        = string
  description = "Path to the SSH private key for connecting to the VMs."
}

### Variables to Configure IP Addresses for Master Node(s) and Worker Nodes. 

variable "master_ip_list" {
  description = "IP address list for the Kubernetes master node"
  type        = list(string)

  validation {
    condition     = length(var.master_ip_list) % 2 != 0
    error_message = "The number of master nodes must be an odd number (1, 3, 5, etc.) to ensure a stable etcd quorum."
  }
}

variable "worker_ip_list" {
  description = "IP address list for the Kubernetes worker nodes"
  type        = list(string)
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
  default     = 4096
}

variable "worker_vcpu" {
  description = "Number of vCPUs for each Kubernetes worker node"
  type        = number
  default     = 4
}

variable "worker_ram" {
  description = "Amount of RAM (in MB) for each Kubernetes worker node"
  type        = number
  default     = 4096
}

# Automatically set the variable for Terraform VMs

variable "nat_gateway" {
  description = "The gateway IP address for the NAT network (vmnet8)."
  type        = string
}

variable "nat_subnet_prefix" {
  description = "The first three octets of the NAT subnet (e.g., '172.16.86')."
  type        = string
}

variable "k8s_ha_virtual_ip" {
  description = "The virtual IP address for the Kubernetes API server load balancer."
  type        = string
}

variable "k8s_pod_subnet" {
  description = "The CIDR block for the Kubernetes pod network."
  type        = string
}

variable "qemu_base_image_path" {
  description = "Path to the Packer-built qcow2 image for KVM"
  type        = string
}

variable "hostonly_network_name" {
  description = "Name for the Host-only libvirt network"
  type        = string
  default     = "iac-kubeadm-hostonly-net"
}

variable "kvm_hostonly_cidr" {
  description = "CIDR for the KVM host-only network, should match the subnet of master/worker IPs"
  type        = string
  default     = "172.16.134.0/24"
}
