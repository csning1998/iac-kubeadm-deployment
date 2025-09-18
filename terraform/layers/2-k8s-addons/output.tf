
# output "dashboard_admin_token" {
#   description = "Token for the Kubernetes Dashboard admin user"
#   value       = module.k8s_dashboard.admin_user_token
#   sensitive   = true
# }

output "ingress_node_ports" {
  description = "Node ports for the Ingress NGINX controller"
  value       = module.k8s_ingress_nginx.service_node_ports
}
