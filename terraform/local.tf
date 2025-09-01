locals {
  vms_dir        = "${path.root}/vms"
  master_ip_list = var.master_ip_list
  worker_ip_list = var.worker_ip_list
  vmx_image_path = abspath("${path.root}/../packer/output/ubuntu-server-vmware/ubuntu-server-k8s-based.vmx")
  ansible_path   = abspath("${path.root}/../ansible/")

  master_config = [
    for idx, ip in local.master_ip_list : {
      key  = "k8s-master-${format("%02d", idx)}"
      ip   = ip
      vcpu = var.master_vcpu
      ram  = var.master_ram
      path = "${local.vms_dir}/k8s-master-${format("%02d", idx)}/k8s-master-${format("%02d", idx)}.vmx"
    }
  ]

  workers_config = [
    for idx, ip in local.worker_ip_list : {
      key  = "k8s-worker-${format("%02d", idx)}"
      ip   = ip
      vcpu = var.worker_vcpu
      ram  = var.worker_ram
      path = "${local.vms_dir}/k8s-worker-${format("%02d", idx)}/k8s-worker-${format("%02d", idx)}.vmx"
    }
  ]
  all_nodes = concat(local.master_config, local.workers_config)
}
