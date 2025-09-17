
output "dashboard_admin_token" {
  description = "Token for the Kubernetes Dashboard admin user"
  value       = module.k8s_dashboard.admin_user_token
  sensitive   = true
}
