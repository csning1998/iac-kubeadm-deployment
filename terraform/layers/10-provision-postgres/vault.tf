data "vault_generic_secret" "iac_vars" {
  path = "secret/on-premise-gitlab-deployment/variables"
}

data "vault_generic_secret" "db_vars" {
  path = "secret/on-premise-gitlab-deployment/databases"
}
