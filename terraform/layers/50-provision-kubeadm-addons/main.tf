
module "k8s_calico" {
  source     = "../../modules/51-kubeadm-tigera-calico"
  pod_subnet = data.terraform_remote_state.cluster_provision.outputs.k8s_pod_subnet
}

module "k8s_metric_server" {
  source     = "../../modules/52-kubeadm-metric-server"
  depends_on = [module.k8s_calico]
}

module "k8s_ingress_nginx" {
  source     = "../../modules/23-kubeadm-ingress-nginx"
  depends_on = [module.k8s_calico]
}

module "k8s_dashboard" {
  source             = "../../modules/54-kubeadm-dashboard"
  dashboard_hostname = "dashboard.k8s.local"
  depends_on = [
    module.k8s_calico,
    module.k8s_ingress_nginx
  ]
}
