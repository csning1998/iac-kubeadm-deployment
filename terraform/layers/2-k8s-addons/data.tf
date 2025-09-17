data "terraform_remote_state" "cluster_provision" {
  backend = "local"
  config = {
    path = "../1-cluster-provision/terraform.tfstate"
  }
}
