output "all_nodes_map" {
  description = "List of all provisioned KVM nodes"
  value = [
    for key, node in libvirt_domain.nodes : {
      key  = key
      ip   = var.vm_config.all_nodes_map[key].ip
      ram  = var.vm_config.all_nodes_map[key].ram
      vcpu = var.vm_config.all_nodes_map[key].vcpu
      path = ""
    }
  ]
}

output "vm_status_trigger" {
  description = "A trigger to indicate completion of VM provisioning"
  value       = { for key, domain in libvirt_domain.nodes : key => domain.id }
}
