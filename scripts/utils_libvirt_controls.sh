#!/bin/bash

# This script contains functions for controlling KVM/libvirt services and VMs.

# Resources Mapping
declare -A DOMAIN_MAP=(
  ["10-provision-kubeadm"]="kubeadm-"
  ["10-provision-harbor"]="harbor-"
  ["10-provision-postgres"]="postgres- haproxy- etcd-"
  ["10-provision-redis"]="redis-"
)

# Storage Pool names.
declare -A POOL_MAP=(
  ["10-provision-kubeadm"]="iac-kubeadm"
  ["10-provision-harbor"]="iac-harbor"
  ["10-provision-postgres"]="iac-postgres"
  ["10-provision-redis"]="iac-redis"
)

# Network prefixes.
declare -A NET_MAP=(
  ["10-provision-kubeadm"]="iac-kubeadm"
  ["10-provision-harbor"]="iac-harbor"
  ["10-provision-postgres"]="iac-postgres"
  ["10-provision-redis"]="iac-redis"
)

# Function: Ensure libvirt service is running before executing a command.
ensure_libvirt_services_running() {
  echo "#### Checking status of libvirt service..."

  # Use 'is-active' for a clean check without parsing text.
  if ! sudo systemctl is-active --quiet libvirtd; then
    echo "--> libvirt service is not running. Attempting to start it..."
    
    # Use 'sudo' as this is a system-level service.
    if sudo systemctl start libvirtd; then
      echo "--> libvirt service started successfully."
      # Give the service a moment to initialize networks.
      sleep 2
    else
      echo "--> ERROR: Failed to start libvirt service. Please check 'systemctl status libvirtd'."
      # Exit the script if the core dependency cannot be started.
      exit 1
    fi
  else
    echo "--> libvirt service is already running."
  fi
}

# Function: Forcefully clean up all libvirt resources associated with this project.
purge_libvirt_resources() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <target1> [target2...] | all"
    echo "Available targets: ${!DOMAIN_MAP[@]}"
    return 1
  fi

  local targets_to_process=("$@")
  local domain_prefixes_to_purge=()
  local pool_names_to_purge=()
  local net_prefixes_to_purge=()

  # --- 1. Build lists of resources to purge based on input ---
  echo ">>> STEP: Parsing targets and building resource lists..."
  for target in "${targets_to_process[@]}"; do
    if [[ "$target" == "all" ]]; then
      echo "#### Target 'all' selected. Preparing to purge all known resources."
      domain_prefixes_to_purge+=(${DOMAIN_MAP[@]})
      pool_names_to_purge+=(${POOL_MAP[@]})
      net_prefixes_to_purge+=(${NET_MAP[@]})
      break # 'all' overrides everything else
    fi

    if [[ -v "DOMAIN_MAP[$target]" ]]; then
      echo "#### Adding resources for target: $target"
      domain_prefixes_to_purge+=(${DOMAIN_MAP[$target]})
      pool_names_to_purge+=(${POOL_MAP[$target]})
      net_prefixes_to_purge+=(${NET_MAP[$target]})
    else
      echo "Warning: Unknown target '$target'. Skipping."
    fi
  done

  # --- 2. Deduplicate the resource lists ---
  local unique_domain_prefixes=$(echo "${domain_prefixes_to_purge[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
  local unique_pool_names=$(echo "${pool_names_to_purge[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
  local unique_net_prefixes=$(echo "${net_prefixes_to_purge[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

  # --- 3. Purge VMs (Domains) ---
  echo ">>> STEP: Purging Virtual Machines (Domains)..."
  for prefix in ${unique_domain_prefixes}; do
    for vm in $(sudo virsh list --all --name | grep "^${prefix}" || true); do
      if [[ -n "$vm" ]]; then
        echo "#### Destroying and undefining VM: $vm"
        sudo virsh destroy "$vm" >/dev/null 2>&1 || true
        sudo virsh undefine "$vm" --nvram --remove-all-storage >/dev/null 2>&1 || true
      fi
    done
  done

  # --- 4. Purge Storage Volumes and Pools ---
  echo ">>> STEP: Purging Storage Volumes and Pools..."
  for pool in ${unique_pool_names}; do
    if sudo virsh pool-info "$pool" >/dev/null 2>&1; then
      # Delete all volumes within the pool
      for vol in $(sudo virsh vol-list "$pool" | awk 'NR>2 {print $1}' || true); do
        if [[ -n "$vol" ]]; then
          echo "#### Deleting volume: $vol from pool $pool"
          sudo virsh vol-delete --pool "$pool" "$vol" >/dev/null 2>&1 || true
        fi
      done
      # Destroy and undefine the pool itself
      echo "#### Destroying and undefining pool: $pool"
      sudo virsh pool-destroy "$pool" >/dev/null 2>&1 || true
      sudo virsh pool-undefine "$pool" >/dev/null 2>&1 || true
    else
      echo "#### Storage pool $pool does not exist, skipping."
    fi
  done

  # --- 5. Purge Networks ---
  echo ">>> STEP: Purging Networks..."
  for prefix in ${unique_net_prefixes}; do
    for suffix in "hostonly-net" "nat-net"; do
      local net_name="${prefix}-${suffix}"
      if sudo virsh net-info "$net_name" >/dev/null 2>&1; then
        echo "#### Destroying and undefining network: $net_name"
        sudo virsh net-destroy "$net_name" >/dev/null 2>&1 || true
        sudo virsh net-undefine "$net_name" >/dev/null 2>&1 || true
      fi
    done
  done

  echo "--------------------------------------------------"
  echo "#### Libvirt resource purge complete."
  echo "--------------------------------------------------"
}