#!/bin/bash

# --- Global Vault Variables ---
readonly VAULT_KEYS_DIR="${SCRIPT_DIR}/vault/keys"
readonly VAULT_INIT_OUTPUT_FILE="${VAULT_KEYS_DIR}/init-output.json"
readonly VAULT_UNSEAL_KEYS_FILE="${VAULT_KEYS_DIR}/unseal.key"
readonly VAULT_ROOT_TOKEN_FILE="${VAULT_KEYS_DIR}/root-token.txt"

# Function: Display the current status of the Vault server.
display_vault_status() {
  local status_color_red='\033[0;31m'
  local status_color_green='\033[0;32m'
  local status_color_yellow='\033[0;33m'
  local color_reset='\033[0m'
  local status_message
  local vault_status_json

  if [ -z "${VAULT_ADDR:-}" ]; then
    status_message="${status_color_yellow}Cannot check - VAULT_ADDR not set${color_reset}"
  elif vault_status_json=$(vault status -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" -format=json 2>/dev/null) || true; then
    if [[ -n "$vault_status_json" ]]; then
      sealed=$(echo "$vault_status_json" | jq .sealed)
      if [[ "$sealed" == true ]]; then
        status_message="${status_color_yellow}Running (Sealed)${color_reset}"
      else
        status_message="${status_color_green}Running (Unsealed)${color_reset}"
      fi
    else
      status_message="${status_color_red}Stopped or Unreachable${color_reset}"
    fi
  fi

  echo -e "Vault Server Status: ${status_message}"
}

# Function: Idempotently ensure the KVv2 secrets engine is enabled at 'secret/'.
ensure_kv_engine_enabled() {
  echo ">>> Ensuring KV secrets engine is enabled at 'secret/'..."
  if ! vault secrets list -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" -format=json | jq -e '."secret/"' > /dev/null; then
    echo "#### 'secret/' path not found, enabling kv-v2 secrets engine..."
    vault secrets enable -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" -path=secret kv-v2
  else
    echo "#### kv-v2 secrets engine at 'secret/' is already enabled."
  fi
}

# Function (ONCE-ONLY): Initialize, unseal, and configure a new Vault server.
initialize_vault() {
  echo ">>> STEP: Vault First-Time Initialization..."
  echo
  echo "############################################################################"
  echo "### Proceeding will DESTROY ALL existing data and generate new keys.     ###"
  echo "############################################################################"
  echo 
  read -p "### Type 'yes' to confirm and proceed with re-initialization: " confirmation
  if [[ "$confirmation" != "yes" ]]; then
    echo "#### Re-initialization cancelled."
    return 1
  fi

  echo "#### Initializing Vault..."
  vault operator init -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" -format=json > "$VAULT_INIT_OUTPUT_FILE"

  jq -r .unseal_keys_b64[] "$VAULT_INIT_OUTPUT_FILE" > "$VAULT_UNSEAL_KEYS_FILE"
  chmod 600 "$VAULT_UNSEAL_KEYS_FILE"
  jq -r .root_token "$VAULT_INIT_OUTPUT_FILE" > "$VAULT_ROOT_TOKEN_FILE"
  chmod 600 "$VAULT_ROOT_TOKEN_FILE"

  echo "#### Automatically updating VAULT_TOKEN in .env file..."
  local new_token
  new_token=$(cat "$VAULT_ROOT_TOKEN_FILE")
  update_env_var "VAULT_TOKEN" "${new_token}"

  echo "#### Unsealing the new Vault instance..."
  unseal_vault

  # Login into Vault
  vault login -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" ${new_token}

  ensure_kv_engine_enabled

  echo "####"
  echo "#### Vault is initialized and ready."
  echo "#### Next Step: Manually run 'vault kv put secret/iac-kubeadm/variables ...' with your secrets."
  echo "####"
}

# Function: Unseal a user-started Vault instance.
unseal_vault() {
  echo ">>> STEP: Unsealing Vault..."
  if [ ! -f "$VAULT_UNSEAL_KEYS_FILE" ]; then
    echo "#### ERROR: Unseal keys not found. Run 'Initialize Vault' first." >&2; return 1;
  fi

  if [[ "$(vault status -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" -format=json 2>/dev/null | jq .sealed)" == "true" ]]; then
    echo "#### Vault is sealed. Unsealing with saved keys...";
    mapfile -t keys < "$VAULT_UNSEAL_KEYS_FILE";
    vault operator unseal -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" "${keys[0]}";
    vault operator unseal -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" "${keys[1]}";
    vault operator unseal -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" "${keys[2]}";
    echo "#### Unseal process complete.";
  else
    echo "#### Vault is already unsealed or unreachable.";
  fi
}