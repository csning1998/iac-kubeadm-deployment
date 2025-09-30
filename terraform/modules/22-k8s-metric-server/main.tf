
resource "helm_release" "metrics_server" {

  # Ref: https://artifacthub.io/packages/helm/metrics-server/metrics-server

  name            = "metrics-server"
  repository      = "https://kubernetes-sigs.github.io/metrics-server/"
  chart           = "metrics-server"
  namespace       = "kube-system"
  version         = "3.13.0"
  cleanup_on_fail = true

  values = [
    # Allow the chart metrics-server to connect to the kubelet's metrics endpoint
    yamlencode({
      # Will be fixed soon
      args = ["--kubelet-insecure-tls"]
    })
  ]
}
