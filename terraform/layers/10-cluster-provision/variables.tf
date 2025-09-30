
# Kubernetes Cluster Topology & Configuration

variable "k8s_cluster_config" {
  description = "Define all nodes including virtual hardware resources"
  type = object({
    cluster_name = string
    nodes = object({
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
    base_image_path = optional(string, "../../../packer/output/20-k8s-base/ubuntu-server-24-20-k8s-base.qcow2")
    ha_virtual_ip   = string
    pod_subnet      = optional(string, "10.244.0.0/16")
  })

  validation {
    condition     = length(var.k8s_cluster_config.nodes.masters) % 2 != 0
    error_message = "The number of master nodes must be an odd number (1, 3, 5, etc.) to ensure a stable etcd quorum."
  }
}

# Kubernetes Cluster Infrastructure Network Configuration

variable "cluster_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the Kuberentes Cluster."
  type = object({
    network = object({
      nat = object({
        name        = string
        cidr        = string
        bridge_name = string

      })
      hostonly = object({
        name        = string
        cidr        = string
        bridge_name = string
      })
    })
    storage_pool_name = optional(string, "iac-kubeadm")
  })
}
