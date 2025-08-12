#!/bin/bash

# This script contains general utility and helper functions.

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
