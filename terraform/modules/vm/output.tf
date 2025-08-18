output "all_nodes" {
  description = "List of all nodes (master and workers)"
  value       = var.all_nodes
}

output "master_config" {
  description = "Configuration for master nodes"
  value = [
    for idx, ip in var.master_ip_list : {
      key  = "k8s-master-${format("%02d", idx)}"
      ip   = ip
      vcpu = var.master_vcpu
      ram  = var.master_ram
      path = "${var.vms_dir}/k8s-master-${format("%02d", idx)}/k8s-master-${format("%02d", idx)}.vmx"
    }
  ]
}

output "worker_config" {
  description = "Configuration for worker nodes"
  value = [
    for idx, ip in var.worker_ip_list : {
      key  = "k8s-worker-${format("%02d", idx)}"
      ip   = ip
      vcpu = var.worker_vcpu
      ram  = var.worker_ram
      path = "${var.vms_dir}/k8s-worker-${format("%02d", idx)}/k8s-worker-${format("%02d", idx)}.vmx"
    }
  ]
}

output "vm_status" {
  description = "The status ID of the VM readiness check resource."
  value       = null_resource.prepare_ssh_access.id
}
