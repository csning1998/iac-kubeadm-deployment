
# Registry Server Topology & Configuration

variable "redis_cluster_config" {
  description = "Define the registry server including virtual hardware resources."
  type = object({
    cluster_name = string
    nodes = object({
      redis = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = optional(string, "../../../packer/output/05-base-redis/ubuntu-server-24-05-base-redis.qcow2")
  })
  validation {
    condition     = length(var.redis_cluster_config.nodes.redis) % 2 != 0
    error_message = "The number of master nodes must be an odd number (1, 3, 5, etc.) to ensure a stable Sentinel quorum."
  }
}

# Registry Server Infrastructure Network Configuration

variable "redis_infrastructure" {
  description = "All Libvirt-level infrastructure configurations for the Redis Service."
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
    redis_allowed_subnet = optional(string, "172.16.137.0/24")
    storage_pool_name    = optional(string, "iac-redis")
  })
}
