# This file defines variables used in the Packer build process.
# Pay attention to network-related variables and boot commands,
# as misconfigurations can lead to the build blocking or timing out.

variable "vm_name" {
  type        = string
  description = "Base name for the virtual machine and its output files."
}

# --- ISO Configuration ---

variable "iso_url" {
  type        = string
  description = "URL of the Ubuntu Server ISO."
}

variable "iso_checksum" {
  type        = string
  description = "SHA256 checksum of the ISO file."
}

# --- Hardware Configuration ---

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

variable "scripts" {
  type        = list(string)
  default     = null
  description = "Shell scripts to run after the OS has been installed"
}

variable "os_name" {
  type        = string
  default     = "ubuntu"
  description = "The name of the OS"
}

variable "os_version" {
  type        = string
  default     = "24.04"
  description = "The version of the OS"
}

variable "build_timestamp" {
  type        = string
  default     = ""
  description = "Timestamp of when the image was built"
}
