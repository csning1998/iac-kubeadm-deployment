data "terraform_remote_state" "cluster_provision" {
  backend = "local"
  config = {
    path = "../10-cluster-provision/terraform.tfstate"
  }
}
