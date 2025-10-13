#!/bin/bash

# This script contains general utility and helper functions.

readonly SSH_CONFIG="$HOME/.ssh/config"
# readonly KNOWN_HOSTS_FILE="$HOME/.ssh/k8s_cluster_known_hosts"

# Function: Check if the required SSH private key exists
check_ssh_key_exists() {
  if [ -z "$SSH_PRIVATE_KEY" ]; then
      echo "#### Error: SSH_PRIVATE_KEY variable is not set."
      return 1
  fi

  if [ ! -f "$SSH_PRIVATE_KEY" ]; then
    echo "#### Error: SSH private key for automation not found at '$SSH_PRIVATE_KEY'"
    echo "#### Please use the 'Generate SSH Key' menu option first, or configure the correct key name in 'scripts/config.sh'."
    return 1
  fi
  # If the key exists, return success (0)
  return 0
}

# Function: Generate an SSH key for IaC automation (unattended mode)
generate_ssh_key() {
  local default_key_name="id_ed25519_iac-kubeadm-deployment"
  local key_name

  echo "#### This utility will generate an SSH key for IaC automation (unattended mode)."
  read -p "#### Enter the desired key name (default: ${default_key_name}): " key_name
  
  key_name=${key_name:-$default_key_name}
  
  local private_key_path="${HOME}/.ssh/${key_name}"
  local public_key_path="${private_key_path}.pub"

  if [ -f "$private_key_path" ]; then
    echo "#### Warning: Key file '${private_key_path}' already exists."
    read -p "#### Overwrite? (y/n): " overwrite_answer
    if [[ ! "$overwrite_answer" =~ ^[Yy]$ ]]; then
      echo "#### Skipping key generation."
      return
    fi
  fi

  echo "#### Generating key at '${private_key_path}'..."
  ssh-keygen -t ed25519 -f "$private_key_path" -C "$key_name" -N ""
  
  echo "#### Key generated successfully:"
  ls -l "$private_key_path" "$public_key_path"
  echo "--------------------------------------------------"
  echo ">>> Updating SSH_PRIVATE_KEY in .env file to: ${private_key_path}"
  # Call the helper function to update the .env file
  update_env_var "SSH_PRIVATE_KEY" "${private_key_path}"

  echo "#### IMPORTANT: Please update your configuration file"
  echo "####   e.g., in 'packer/secret.auto.pkrvars.hcl' or terraform/*.tfvars"
  echo "#### to use the following paths:"
  echo "In Terraform: ssh_private_key_path = \"${private_key_path}\""
  echo "In Packer: ssh_public_key_path  = \"${public_key_path}\""
  echo "--------------------------------------------------"
}

# Function: Verify SSH access to hosts defined in ~/.ssh/iac-kubeadm-deployment_config
verify_ssh() {
  echo ">>> STEP: Performing strict SSH access verification for all IaC configurations..."

  local ssh_config_file
  # Use an array to handle cases where no files are found
  readarray -t ssh_config_files < <(find "$HOME/.ssh" -maxdepth 1 -name "iac-kubeadm-*_config")

  if [ ${#ssh_config_files[@]} -eq 0 ]; then
    echo "#### Error: No IaC SSH config files found matching '$HOME/.ssh/iac-kubeadm-*_config'."
    return 1
  fi

  local all_checks_passed=true

  for ssh_config_file in "${ssh_config_files[@]}"; do
    echo "--------------------------------------------------"
    echo "#### Verifying configuration: $(basename "${ssh_config_file}")"

    # Dynamically extract the UserKnownHostsFile from the config itself.
    local raw_path
    raw_path=$(awk '/UserKnownHostsFile/ {print $2; exit}' "${ssh_config_file}")

    # Manually expand the tilde (~) to the user's home directory.
    local known_hosts_file="${raw_path/#\~/$HOME}"

    if [ ! -f "${known_hosts_file}" ]; then
      echo "#### Error: Known hosts file not found at ${known_hosts_file}"
      echo "#### Please ensure the corresponding Terraform layer has been applied successfully."
      all_checks_passed=false
      continue # Skip to the next config file
    fi

    local all_hosts
    all_hosts=$(awk '/^Host / {print $2}' "${ssh_config_file}")

    if [ -z "${all_hosts}" ]; then
      echo "#### Warning: No hosts found in ${ssh_config_file}"
      continue
    fi

    # Loop through each host and test the connection silently.
    while IFS= read -r host; do
      if [ -z "$host" ]; then continue; fi
      
      echo "--> Verifying connection to host: ${host}..."
      # Use ssh with the 'true' command for a quick, non-interactive connection test.
      # The '-n' option is CRITICAL here to prevent ssh from consuming the stdin of the while loop.
      if ssh -n \
          -F "${ssh_config_file}" \
          -o ConnectTimeout=5 \
          -o BatchMode=yes \
          -o PasswordAuthentication=no \
          -o StrictHostKeyChecking=yes \
          -o UserKnownHostsFile="${known_hosts_file}" \
        "$host" true 2>/dev/null; then
        echo "    - SUCCESS: Connected to ${host} via public key."
      else
        echo "    - FAILED: Could not connect to ${host} using strict key-based authentication."
        all_checks_passed=false
      fi
    done <<< "${all_hosts}"
  done

  echo "--------------------------------------------------"
  if [ "${all_checks_passed}" = true ]; then
    echo ">>> All SSH verifications completed successfully."
  else
    echo ">>> One or more SSH verification checks failed."
  fi
  echo "--------------------------------------------------"
}

# Function: Check if user wants to verify SSH connections
prompt_verify_ssh() {
  read -p "#### Do you want to verify SSH connections? (y/n): " answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    verify_ssh
  else
    echo "#### Skipping SSH verification."
  fi
}

# Function: Prepend the Include directive to ~/.ssh/config for the k8s cluster
integrate_ssh_config() {
  # Default to ~/.ssh/config if not set, though it should be set by the caller.
  local k8s_config_path="$1"
  if [[ -z "${k8s_config_path}" ]]; then
    echo "Error: No config path provided to integrate_ssh_config." >&2
    return 1
  fi

  local ssh_config_file="${SSH_CONFIG:-$HOME/.ssh/config}"
  local include_line="Include ${k8s_config_path}"

  # Ensure the directory exists and config file exists
  mkdir -p "$(dirname "${ssh_config_file}")" || {
    echo "Error: Failed to create directory $(dirname "${ssh_config_file}")"
    return 1
  }

  touch "${ssh_config_file}" || {
    echo "Error: Cannot touch ${ssh_config_file}"
    return 1
  }
  chmod 600 "${ssh_config_file}"

  # Check if the Include line already exists in the file.
  if grep -Fxq "${include_line}" "${ssh_config_file}"; then
    echo "OK: '${include_line}' already exists in ${ssh_config_file}."
    return 0
  fi

  echo "Action: Prepending '${include_line}' to ${ssh_config_file}..."

  # Create a temporary file to safely build the new config
  local temp_file
  temp_file=$(mktemp) || {
    echo "Error: Failed to create temporary file."
    return 1
  }

  # Write the new Include line to the temporary file first.
  echo "${include_line}" > "${temp_file}" || {
    echo "Error: Failed to write to temporary file."
    rm "${temp_file}"
    return 1
  }

  # Append the content of the original config file to the temporary file.
  cat "${ssh_config_file}" >> "${temp_file}" || {
    echo "Error: Failed to read from ${ssh_config_file}."
    rm "${temp_file}"
    return 1
  }

  # Atomically replace the old config with the new one.
  mv "${temp_file}" "${ssh_config_file}" || {
    echo "Error: Failed to replace ${ssh_config_file} with the updated version."
    rm "${temp_file}"
    return 1
  }

  # Re-apply strict permissions in case mv changed them
  chmod 600 "${ssh_config_file}"
  echo "Success: SSH config updated."
}

# Function: Remove the Include directive from ~/.ssh/config for the k8s cluster
deintegrate_ssh_config() {
  local k8s_config_path="$1"
  if [[ -z "${k8s_config_path}" ]]; then
    echo "Error: No config path provided to deintegrate_ssh_config." >&2
    return 1
  fi
  
  local ssh_config_file="${SSH_CONFIG:-$HOME/.ssh/config}"
  if [[ -z "${SSH_CONFIG}" ]]; then
    echo "Error: SSH_CONFIG is not defined"
    exit 1
  fi
  
  local include_line="Include ${k8s_config_path}"
  if [[ -f "${ssh_config_file}" ]]; then
    sed -i "\|${include_line}|d" "${ssh_config_file}"
  else
    echo "Warning: ${ssh_config_file} does not exist, skipping removal"
  fi
}

bootstrap_ssh_known_hosts() {
  if [ $# -lt 2 ]; then
    echo "#### Error: Not enough arguments. Usage: bootstrap_ssh_known_hosts <config_name> <ip1> [<ip2>...]" >&2
    return 1
  fi
  if [ $# -eq 0 ]; then
    echo "#### Error: No IP addresses provided to bootstrap_ssh_known_hosts." >&2
    return 1
  fi

  local config_name="$1"
  shift
  local known_hosts_file="$HOME/.ssh/known_hosts_${config_name}"

  echo ">>> Preparing for Ansible: Clearing old host keys and scanning new ones..."
  mkdir -p "$HOME/.ssh"
  rm -f "${known_hosts_file}"
  
  echo "#### Scanning host keys for all nodes..."
  # Iterate through all IP address parameters passed from `terraform/modules/ansible/main.tf`
  for ip in "$@"; do
    echo "#### Waiting for SSH on ${ip} to be ready..."
    for i in {1..30}; do # Wait for up to 30 seconds
      if ssh-keyscan -H "${ip}" >> "${known_hosts_file}" 2>/dev/null; then
        echo "      - Scanned key for ${ip} and added to ${known_hosts_file}"
        break
      fi
      if [ "${i}" -eq 30 ]; then
        echo "#### Error: Timed out waiting for SSH on ${ip}." >&2
        return 1
      fi
      sleep 1
    done
  done
  
  echo "#### Host key scanning complete. File created at ${known_hosts_file}"
  echo "--------------------------------------------------"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -eq 0 ]]; then
    echo "Error: No function specified"
    exit 1
  fi
  "$@"
fi

# Function: Report execution time
report_execution_time() {
  local END_TIME DURATION MINUTES SECONDS
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  MINUTES=$((DURATION / 60))
  SECONDS=$((DURATION % 60))
  echo "--------------------------------------------------"
  echo ">>> Execution time: ${MINUTES}m ${SECONDS}s"
  echo "--------------------------------------------------"
}
