terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
  }
}

locals {
  kubeconfig = yamldecode(data.terraform_remote_state.cluster_provision.outputs.kubeconfig_content)

  # Extracts the single cluster and user from the kubeconfig
  cluster = one(local.kubeconfig.clusters)
  user    = one(local.kubeconfig.users)
}


# Configure the Kubernetes provider using details from the remote state
provider "kubernetes" {
  host                   = local.cluster.cluster.server
  cluster_ca_certificate = base64decode(local.cluster.cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.user.user["client-certificate-data"])
  client_key             = base64decode(local.user.user["client-key-data"])
}

# Configure the Helm provider to use the same Kubernetes provider settings
provider "helm" {
  kubernetes = {
    host                   = local.cluster.cluster.server
    cluster_ca_certificate = base64decode(local.cluster.cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.user.user["client-certificate-data"])
    client_key             = base64decode(local.user.user["client-key-data"])
  }
}
