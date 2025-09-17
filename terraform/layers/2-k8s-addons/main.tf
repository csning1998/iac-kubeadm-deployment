
module "k8s-calico" {
  source     = "../../modules/k8s-calico"
  pod_subnet = data.terraform_remote_state.cluster_provision.outputs.k8s_pod_subnet
}
