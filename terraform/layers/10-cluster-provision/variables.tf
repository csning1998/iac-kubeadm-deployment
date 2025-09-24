
# Kubernetes Cluster Topology & Node Configuration

variable "k8s_cluster_nodes" {
  description = "Define all nodes including virtual hardware resources"
  type = object({
    masters = list(object({
      ip   = string
      vcpu = number
      ram  = number
    }))
    workers = list(object({
      ip   = string
      vcpu = number
      ram  = number
    }))
  })

  validation {
    condition     = length(var.k8s_cluster_nodes.masters) % 2 != 0
    error_message = "The number of master nodes must be an odd number (1, 3, 5, etc.) to ensure a stable etcd quorum."
  }
}

variable "k8s_cluster_vm_base_image_path" {
  description = "Path to the Packer-built qcow2 image for KVM"
  type        = string
  default     = "../../../packer/output/20-k8s-base/ubuntu-server-24-20-k8s-base.qcow2"
}

# Kubernetes Cluster Infrastructure Network Configuration

variable "k8s_cluster_nat_network_name" {
  description = "Name for the NAT libvirt network"
  type        = string
}

variable "k8s_cluster_nat_network_gateway" {
  description = "The gateway IP address for the NAT network."
  type        = string
}

variable "k8s_cluster_nat_network_subnet_prefix" {
  description = "The first three octets of the NAT subnet (e.g., '172.16.86')."
  type        = string
}

variable "k8s_cluster_hostonly_network_name" {
  description = "Name for the Host-only libvirt network"
  type        = string
  default     = "iac-kubeadm-hostonly-net"
}

variable "k8s_cluster_hostonly_network_cidr" {
  description = "CIDR for the KVM host-only network, should match the subnet of master/worker IPs"
  type        = string
  default     = "172.16.134.0/24"
}

# Kubernetes/Application Level Variables

variable "k8s_ha_virtual_ip" {
  description = "The virtual IP address for the Kubernetes API server load balancer."
  type        = string
}

variable "k8s_pod_subnet" {
  description = "The CIDR block for the Kubernetes pod network."
  type        = string
}
