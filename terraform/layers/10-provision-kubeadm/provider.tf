terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.3.0"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

provider "vault" {
  # Vault server address is read from the VAULT_ADDR environment variable
}
