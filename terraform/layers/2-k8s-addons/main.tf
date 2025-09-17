
module "k8s_calico" {
  source     = "../../modules/k8s-calico"
  pod_subnet = data.terraform_remote_state.cluster_provision.outputs.k8s_pod_subnet
}

module "k8s_metric_server" {
  source     = "../../modules/k8s-metric-server"
  depends_on = [module.k8s_calico]
}

module "k8s_ingress_nginx" {
  source     = "../../modules/k8s-ingress-nginx"
  depends_on = [module.k8s_calico]
}

module "k8s_dashboard" {
  source             = "../../modules/k8s-dashboard"
  dashboard_hostname = "dashboard.k8s.local"
  depends_on = [
    module.k8s_calico,
    module.k8s_ingress_nginx
  ]
}
