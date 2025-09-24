
/** 
 * Virtual Machine Configuration
 * Variables defining the specifications and credentials for the VMs.
*/

# Module-level variable definitions

variable "vm_config" {
  description = "All configurations related to the virtual machines being provisioned."
  type = object({
    all_nodes_map = map(object({
      ip   = string
      vcpu = number
      ram  = number
    }))
    base_image_path = string
  })
}

variable "credentials" {
  description = "Access credentials for the virtual machines."
  type = object({
    username            = string
    password            = string
    ssh_public_key_path = string
  })
}

variable "libvirt_infrastructure" {
  description = "All configurations for Libvirt-managed networks and storage."
  type = object({
    network = object({
      nat = object({
        name          = string
        cidr          = string
        gateway       = string
        subnet_prefix = string
      })
      hostonly = object({
        name = string
        cidr = string
      })
    })
    storage_pool_name = string
  })
}
