
# Registry Server Topology & Configuration

variable "harbor_cluster_config" {
  description = "Define the registry server including virtual hardware resources."
  type = object({
    cluster_name = string
    nodes = object({
      harbor = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = optional(string, "../../../packer/output/10-base-microk8s/ubuntu-server-24-10-base-microk8s.qcow2")
  })
  validation {
    condition     = length(var.harbor_cluster_config.nodes.harbor) % 2 != 0
    error_message = "The number of MicroK8s nodes for the Harbor cluster must be an odd number (1, 3, 5, etc.) to ensure a stable dqlite quorum."
  }
}

# Registry Server Infrastructure Network Configuration

variable "registry_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the Registry Server."
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
    storage_pool_name = optional(string, "iac-harbor")
  })
}
