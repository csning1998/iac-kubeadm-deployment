#!/bin/bash

# Extracts confidential variables from Vault for specific playbooks.
extractor_confidential_var() {
  local playbook_file="$1"
  local vault_path="secret/on-premise-gitlab-deployment/databases"
  local extra_vars_string=""
  local secrets_json
  local keys_needed=() # Bash array to hold the keys that need

  # 1. Determine the key to fetch by playbook
  case "${playbook_file}" in
    "10-provision-postgres.yaml")
      echo "#### Postgres playbook detected. Preparing credentials..." >&2
      keys_needed=("pg_superuser_password" "pg_replication_password")
      ;;

    "10-provision-redis.yaml")
      echo "#### Redis playbook detected. Preparing credentials..." >&2
      keys_needed=("redis_requirepass" "redis_masterauth")
      ;;

    *)
      echo "${extra_vars_string}"
      return 0
      ;;
  esac

  # 2. Once-only vault fetching if and only if the keys_needed (case) is non-null
  if ! secrets_json=$(vault kv get -address="${VAULT_ADDR}" -ca-cert="${VAULT_CACERT}" -format=json "${vault_path}"); then
    echo "FATAL: Failed to fetch secrets from Vault at path '${vault_path}'. Is Vault unsealed?" >&2
    return 1
  fi

  # 3. Process Key, validation, and then establish the extra-vars string
  for key in "${keys_needed[@]}"; do
    local value
    value=$(echo "${secrets_json}" | jq -r ".data.data.${key}")

    if [[ -z "${value}" || "${value}" == "null" ]]; then
      echo "FATAL: Could not find required key '${key}' in Vault at '${vault_path}'." >&2
      return 1
    fi

    extra_vars_string+=" --extra-vars '${key}=${value}'"
  done

  echo "#### Credentials fetched successfully." >&2
  
  echo "${extra_vars_string}"
  return 0
}

# [Dev] This function is for faster reset and re-execute the Ansible Playbook
run_ansible_playbook() {
  local playbook_file="$1"  # (e.g., "10-provision-kubeadm.yaml").
  local inventory_file="$2" # (e.g., "inventory-kubeadm-cluster.yaml").

  if [ -z "$playbook_file" ] || [ -z "$inventory_file" ]; then
    echo "FATAL: Playbook or inventory file not specified for run_ansible_playbook function." >&2
    return 1
  fi

  local private_key_path="${SSH_PRIVATE_KEY}"
  local relative_inventory_path="ansible/${inventory_file}"
  local relative_playbook_path="ansible/playbooks/${playbook_file}"
  local full_inventory_path="${SCRIPT_DIR}/${relative_inventory_path}"

  if [ ! -f "${SCRIPT_DIR}/${relative_playbook_path}" ]; then
    echo "FATAL: Playbook not found at '${relative_playbook_path}'" >&2
    return 1
  fi
  if [ ! -f "${full_inventory_path}" ]; then
    echo "FATAL: Inventory not found at '${full_inventory_path}'" >&2
    return 1
  fi

  # --- STEP 1: Derive the config_name from the inventory filename ---
  local config_name
  config_name=$(basename "${inventory_file}" | sed 's/^inventory-//;s/\.yaml$//')

  # --- STEP 2: Use ansible-inventory to reliably get all host IPs ---
  local all_hosts
  all_hosts=$(ansible-inventory -i "${full_inventory_path}" --list | \
              jq -r '._meta.hostvars | to_entries[] | .value.ansible_host // .key')

  if [ -z "${all_hosts}" ]; then
    echo "FATAL: No hosts could be parsed from the inventory file via 'ansible-inventory'." >&2
    return 1
  fi
  
  echo "==========================="
  echo "Derived Config Name: ${config_name}"
  echo "Detected Hosts for SSH scan: $(echo ${all_hosts} | tr '\n' ' ')"
  echo "==========================="

  local hosts_array=()
  readarray -t hosts_array <<< "${all_hosts}"

  # --- STEP 3: Call the function used by Terraform ---
  bootstrap_ssh_known_hosts "${config_name}" "skip_poll" "${hosts_array[@]}"

  echo ">>> STEP: Running Ansible Playbook [${playbook_file}] with inventory [${inventory_file}]"

  local extra_vars
  if ! extra_vars=$(extractor_confidential_var "${playbook_file}"); then
    return 1  # the extractor func will print its err
  fi

  local cmd="ansible-playbook \
    -i ${relative_inventory_path} \
    --private-key ${private_key_path} \
    ${extra_vars} \
    ${relative_playbook_path} \
    -vv"

  run_command "${cmd}" "${SCRIPT_DIR}"
  echo "#### Playbook execution finished."
}

# Function: Display a sub-menu to select and run a Layer 10 playbook.
selector_playbook() {
  local inventory_options=()
  
  local inventory_dir="${ANSIBLE_DIR}" 

  for f in "${inventory_dir}/inventory-"*"-cluster.yaml"; do
    if [ -e "$f" ]; then
      inventory_options+=("$(basename "$f")")
    fi
  done
  inventory_options+=("Back to Main Menu")

  local PS3_SUB=">>> Select a Cluster Inventory to run its Playbook: "
  echo
  select inventory in "${inventory_options[@]}"; do
    
    if [ "$inventory" == "Back to Main Menu" ]; then
      echo "# Returning to main menu..."
      break
    
    elif [ -n "$inventory" ]; then
      
      local target_key
      target_key=$(echo "${inventory}" | sed -e 's/^inventory-//' -e 's/-cluster\.yaml$//')
      
      local playbook="10-provision-${target_key}.yaml"
      
      echo "==========================="
      echo "Selected Inventory: ${inventory}"
      echo "Derived Playbook:   ${playbook}"
      echo "==========================="
      
      run_ansible_playbook "$playbook" "$inventory"
      break

    else
      echo "Invalid option $REPLY"
      continue
    fi
  done
}
