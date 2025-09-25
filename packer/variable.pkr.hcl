
# This file defines all variables for the data-driven Packer build.

# Build Control Variables 

variable "build_spec" {
  type = object({
    suffix   = string
    vnc_port = number
  })
  description = "Defines the specific parameters for this build type."
}

# Common Variables, from *.pkrvars.hcl or command line

variable "common_spec" {
  type = object({
    vm_name      = string
    iso_url      = string
    iso_checksum = string
    cpus         = number
    memory       = number
    disk_size    = number
  })
  description = "Defines common parameters shared across all builds."
}
