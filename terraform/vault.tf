data "vault_generic_secret" "iac_vars" {
  path = "secret/iac-kubeadm-deployment/variables"
}
