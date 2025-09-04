packer {
  required_version = ">= 1.7.0"
  required_plugins {
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
    qemu = {
      version = ">= 1.1.4"
      source  = "github.com/hashicorp/qemu"
    }
  }
}