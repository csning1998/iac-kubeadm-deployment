output "service_node_ports" {
  description = "NodePort mappings for the Ingress NGINX controller service."
  value = {
    for port in data.kubernetes_service_v1.ingress_nginx_controller.spec[0].port : port.name => port.node_port
  }
}
