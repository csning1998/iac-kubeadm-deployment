
resource "helm_release" "ingress_nginx" {

  # Ref: https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx

  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.13.1"
  cleanup_on_fail  = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "NodePort"
        }
      }
    })
  ]
}

# Search for Ingress NGINX Controller Service created by Helm Chart
data "kubernetes_service_v1" "ingress_nginx_controller" {
  metadata {
    name      = "${helm_release.ingress_nginx.name}-controller"
    namespace = helm_release.ingress_nginx.namespace
  }

  depends_on = [
    helm_release.ingress_nginx
  ]
}
