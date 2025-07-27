terraform {
  required_providers {
    virtualbox = {
      source  = "shekeriev/virtualbox"
      version = "0.0.4"
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

  image = "../packer/output/ubuntu-24/ubuntu-server-24-template.ova"
  
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
  description = "Host-Only IP addresses of the deployed VMs"
  value = {
    for name, vm in virtualbox_vm.k8s_nodes :
    name => vm.network_adapter[1].ipv4_address
  }
}