#!/bin/bash

# This script contains general utility and helper functions.

readonly SSH_CONFIG="$HOME/.ssh/config"
readonly KNOWN_HOSTS_FILE="$HOME/.ssh/k8s_cluster_known_hosts"

# Function: Check if VMWare Workstation is installed
check_vmware_workstation() {
  # Check VMware Workstation
  if command -v vmware >/dev/null 2>&1; then
    vmware_version=$(vmware --version 2>/dev/null || echo "Unknown")
    echo "#### VMware Workstation: Installed (Version: $vmware_version)"
  else
    vmware_version="Not installed"
    echo "#### VMware Workstation: Not installed"
    echo "Prior to executing other options, registration is required on Broadcom.com to download and install VMWare Workstation Pro 17.5+."
    echo "Link: https://support.broadcom.com/group/ecx/my-dashboard"
    read -n 1 -s -r -p "Press any key to continue..."
    exit 1
  fi
}

# Function: Verify SSH access to hosts defined in ~/.ssh/k8s_cluster_config
verify_ssh() {
  echo ">>> STEP: Performing simple SSH access check..."
  local ssh_config_file="$HOME/.ssh/k8s_cluster_config"

  if [ ! -f "$ssh_config_file" ]; then
    echo "#### Error: SSH config file not found at $ssh_config_file"
    return 1
  fi

  # Extract host aliases from the config file.
  local all_hosts
  all_hosts=$(awk '/^Host / {print $2}' "$ssh_config_file")

  if [ -z "$all_hosts" ]; then
    echo "#### Error: No hosts found in $ssh_config_file"
    return 1
  fi

  # Loop through each host and test the connection silently.
  while IFS= read -r host; do
    if [ -z "$host" ]; then continue; fi

    # Use ssh with the 'true' command for a quick, non-interactive connection test.
    # The '-n' option is CRITICAL here to prevent ssh from consuming the stdin of the while loop.
    if ssh -n \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
      "$host" true >/dev/null 2>&1; then
      # On success, print in the requested format.
      echo "######## hostname: ${host}"
    else
      # On failure, print an error message.
      echo "######## FAILED to connect to hostname: ${host}"
    fi
  done <<< "$all_hosts"

  echo "#### SSH verification complete."
  echo "--------------------------------------------------"
}

# Function: Check if user wants to verify SSH connections
prompt_verify_ssh() {
  read -p "#### Do you want to verify SSH connections? (y/n): " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    verify_ssh
  else
    echo "#### Skipping SSH verification."
  fi
}

# Function: Add the Include directive to `~/.ssh/config` for the k8s cluster
add_cluster_ssh() {
  if [[ -z "$SSH_CONFIG" ]]; then
    echo "Error: SSH_CONFIG is not defined"
    exit 1
  fi

  mkdir -p "$(dirname "$SSH_CONFIG")" || {
    echo "Error: Failed to create directory $(dirname "$SSH_CONFIG")"
    exit 1
  }

  touch "$SSH_CONFIG" || {
    echo "Error: Cannot touch $SSH_CONFIG"
    exit 1
  }

  local include_line="Include $HOME/.ssh/k8s_cluster_config"
  if ! grep -Fxq "$include_line" "$SSH_CONFIG"; then
    echo "Appending '$include_line' to $SSH_CONFIG"
    echo "$include_line" >> "$SSH_CONFIG" || {
      echo "Error: Failed to append to $SSH_CONFIG"
      exit 1
    }
  else
    echo "Include line already exists in $SSH_CONFIG"
  fi
}

# Function: Remove the Include directive from ~/.ssh/config for the k8s cluster
remove_cluster_ssh() {
  if [[ -z "$SSH_CONFIG" ]]; then
    echo "Error: SSH_CONFIG is not defined"
    exit 1
  fi

  local include_line="Include $HOME/.ssh/k8s_cluster_config"
  if [[ -f "$SSH_CONFIG" ]]; then
    echo "Removing '$include_line' from $SSH_CONFIG"
    sed -i "\|$include_line|d" "$SSH_CONFIG" || {
      echo "Error: Failed to remove line from $SSH_CONFIG"
      exit 1
    }
  else
    echo "Warning: $SSH_CONFIG does not exist, skipping removal"
  fi
}

prepare_ansible_known_hosts() {
  if [ $# -eq 0 ]; then
    echo "#### Error: No IP addresses provided to prepare_ansible_known_hosts."
    return 1
  fi
  
  echo ">>> Preparing for Ansible: Clearing old host keys and scanning new ones..."
  mkdir -p "$HOME/.ssh"
  rm -f "$KNOWN_HOSTS_FILE"
  
  echo "#### Waiting 15 seconds for SSH daemons to be ready..."
  sleep 15
  
  echo "#### Scanning host keys for all nodes..."
  # Iterate through all IP address parameters passed from `terraform/modules/ansible/main.tf`
  for ip in "$@"; do
    echo "      - Scanning $ip"
    ssh-keyscan -H "$ip" >> "$KNOWN_HOSTS_FILE"
  done
  
  echo "#### Host key scanning complete. File created at $KNOWN_HOSTS_FILE"
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
