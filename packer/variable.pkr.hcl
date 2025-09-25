
# This file defines all variables for the data-driven Packer build.

# Build Control Variables 

variable "build_name_suffix" {
  type        = string
  description = "A unique suffix for the build name, output directory, and Ansible group (e.g., '10-registry-base')."
}

variable "vnc_port" {
  type        = number
  description = "The specific VNC port for this build."
}

# Common Variables, from *.pkrvars.hcl or command line

variable "vm_name" {
  type        = string
  description = "Base name for the virtual machine."
}

variable "iso_url" {
  type        = string
  description = "URL of the Ubuntu Server ISO."
}

variable "iso_checksum" {
  type        = string
  description = "SHA256 checksum of the ISO file."
}

variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048 # in MB
}

variable "disk_size" {
  type    = number
  default = 40960 # in MB
}
