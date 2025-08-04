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

# New to Test
output "instance_ips_from_guest_properties" {
  description = "Host-Only IP addresses of the deployed VMs, retrieved via Guest Additions"
  value = {
    for name, vm in virtualbox_vm.k8s_nodes :
    // vm.network_adapter[1] 對應第二張網卡 (索引從 0 開始)
    // Guest Additions 會將其 IP 報告在 Net/1/V4/IP 這個屬性路徑下
    name => vm.network_adapter[1].guest_property["/VirtualBox/GuestInfo/Net/1/V4/IP"]
  }
}

# Old
# output "instance_ips_from_dhcp" {
#   description = "IP addresses from DHCP lease files (likely empty for static config)"
#   value = {
#     for name, vm in virtualbox_vm.k8s_nodes :
#     name => vm.network_adapter[1].ipv4_address
#   }
# }