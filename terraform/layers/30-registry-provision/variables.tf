# Registry Server Topology & Configuration

variable "registry_config" {
  description = "Define the registry server including virtual hardware resources."
  type = object({
    registry_name = string
    nodes = object({
      registry = list(object({
        ip   = string
        vcpu = number
        ram  = number
      }))
    })
    base_image_path = optional(string, "../../../packer/output/10-registry-base/ubuntu-server-24-10-registry-base.qcow2")
  })
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
    storage_pool_name = optional(string, "iac-registry")
  })
}
