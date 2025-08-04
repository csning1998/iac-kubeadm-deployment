terraform {
  required_providers {
    virtualbox = {
      source  = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
  }
}

locals {
  nodes = {
    "node-1" = "192.168.56.101"
    "node-2" = "192.168.56.102"
  }
}

resource "virtualbox_vm" "k8s_nodes" {
  for_each = local.nodes

  image = "../packer/output/ubuntu-server/ubuntu-server-24-template.ova"
  
  name   = each.key
  
  cpus   = 2
  memory = "2048 mib"
  status = "running"

  network_adapter {
    type   = "nat"
    device = "VirtIO"
  }

  network_adapter {
    type           = "hostonly"
    host_interface = "vboxnet0"
    device         = "VirtIO"
  }
}

output "instance_ips" {
  description = "The statically defined Host-Only IP addresses of the deployed VMs"
  value       = local.nodes
}