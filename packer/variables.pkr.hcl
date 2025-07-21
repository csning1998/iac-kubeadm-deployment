# This file defines variables used in the Packer build process.
# Pay attention to network-related variables and boot commands,
# as misconfigurations can lead to the build blocking or timing out.

variable "vm_name" {
  type        = string
  default     = "packer-ubuntu-template"
  description = "Name of the VM in VirtualBox during the build."
}

variable "guest_os_type" {
  type        = string
  default     = "Ubuntu_64"
  description = "The guest OS type for VirtualBox."
}

variable "iso_url" {
  type        = string
  default     = "https://releases.ubuntu.com/noble/ubuntu-24.04.2-live-server-amd64.iso"
  description = "URL of the Ubuntu Server ISO."
}

variable "iso_checksum" {
  type        = string
  default     = "sha256:d6dab0c3a657988501b4bd76f1297c053df710e06e0c3aece60dead24f270b4d"
  description = "SHA256 checksum of the ISO file: \"ubuntu-24.04.2-live-server-amd64.iso\""
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

variable "ssh_username" {
  type        = string
  description = "Specifying the username for ssh. Default username is 'test-username'"
}

variable "user_password" {
  type        = string
  description = "The default password for the default user."
  sensitive   = true
}

variable "user_password_hash" {
  type        = string
  description = "The hashed password for the default user."
  sensitive   = true
}

variable "boot_command" {
  type        = list(string)
  description = "Commands to pass to gui session to initiate automated install. Incorrect boot commands can cause the build to block or fail."
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
