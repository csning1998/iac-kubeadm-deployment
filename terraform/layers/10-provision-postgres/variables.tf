
# Registry Server Topology & Configuration

variable "postgres_cluster_config" {
  description = "Define the registry server including virtual hardware resources."
  type = object({
    cluster_name = string
    nodes = object({
      postgres = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      etcd = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
      haproxy = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = optional(string, "../../../packer/output/04-base-postgres/ubuntu-server-24-04-base-postgres.qcow2")
  })
  # There is no odd number limit for the number of PostgreSQL nodes (e.g. one Primary and multiple Standby nodes)
  validation {
    condition     = length(var.postgres_cluster_config.nodes.etcd) % 2 != 0
    error_message = "The number of master nodes must be an odd number (1, 3, 5, etc.) to ensure a stable etcd quorum."
  }
}

# Registry Server Infrastructure Network Configuration

variable "postgres_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the Postgres Service."
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
    postgres_allowed_subnet = optional(string, "172.16.136.0/24")
    storage_pool_name       = optional(string, "iac-postgres")
  })
}
