
resource "helm_release" "kubernetes_dashboard" {

  # Ref: https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard

  name             = "kubernetes-dashboard"
  repository       = "https://kubernetes.github.io/dashboard/"
  chart            = "kubernetes-dashboard"
  namespace        = "kubernetes-dashboard"
  create_namespace = true
  version          = "7.5.0"
  cleanup_on_fail  = true
}

# Create a ServiceAccount for "admin-user"
resource "kubernetes_service_account" "admin_user" {
  metadata {
    name      = "admin-user"
    namespace = helm_release.kubernetes_dashboard.namespace
  }

  automount_service_account_token = true

  depends_on = [helm_release.kubernetes_dashboard]
}

# Create ClusterRoleBinding to bind "admin-user" as "cluster-admin"
resource "kubernetes_cluster_role_binding" "admin_user" {
  metadata {
    name = "admin-user"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.admin_user.metadata[0].name
    namespace = kubernetes_service_account.admin_user.metadata[0].namespace
  }

  depends_on = [kubernetes_service_account.admin_user]
}

# Create a Secret for ServiceAccount to store pernament Token
resource "kubernetes_secret" "admin_user_token" {
  metadata {
    name      = "admin-user-token"
    namespace = helm_release.kubernetes_dashboard.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_cluster_role_binding.admin_user.metadata[0].name
    }
  }
  type       = "kubernetes.io/service-account-token"
  depends_on = [kubernetes_service_account.admin_user]
}
