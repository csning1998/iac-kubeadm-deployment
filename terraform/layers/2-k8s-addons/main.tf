locals {
  k8s_pod_subnet = data.terraform_remote_state.cluster_provision.outputs.k8s_pod_subnet
}

# Create the tigera-operator namespace
resource "kubernetes_namespace" "tigera_operator" {
  metadata {
    name = "tigera-operator"
  }
}

# Install the tigera-operator directly using the repository URL
resource "helm_release" "tigera_operator" {
  name             = "calico"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  namespace        = kubernetes_namespace.tigera_operator.metadata[0].name
  version          = "v3.28.0"
  create_namespace = false # The namespace is created explicitly above
  cleanup_on_fail  = true

  # Configure the Calico network through the operator's custom resources
  values = [
    yamlencode({
      installation = {
        kubernetesProvider = ""
        cni = {
          type = "Calico"
        }
        calicoNetwork = {
          ipPools = [
            {
              cidr          = local.k8s_pod_subnet
              encapsulation = "VXLAN"
              natOutgoing   = "Enabled"
            }
          ]
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.tigera_operator
  ]
}
