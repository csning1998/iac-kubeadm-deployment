
ui            = true
api_addr      = "https://127.0.0.1:8200"
cluster_addr  = "https://127.0.0.1:8201"
disable_mlock = true

storage "raft" {
  node_id = "node1"
  path    = "./vault/data"
}

listener "tcp" {
  address       = "127.0.0.1:8200"
  tls_disable   = false
  tls_cert_file = "./vault/tls/vault.pem"
  tls_key_file  = "./vault/tls/vault-key.pem"
}
