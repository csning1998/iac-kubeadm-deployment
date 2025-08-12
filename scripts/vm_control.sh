#!/bin/bash

# This script contains functions for controlling VMware Workstation VMs.

# Function: Clean up VMware Workstation VM registrations
cleanup_vmware_vms() {
  echo ">>> STEP: Cleaning up VMware Workstation VM registrations..."
  if vmrun list | grep -q "$PACKER_VM_NAME"; then
    echo "Found leftover Packer VM '$PACKER_VM_NAME'. Stopping and deleting..."
    vmrun stop "${PACKER_OUTPUT_DIR}/${PACKER_VM_NAME}.vmx" hard || true
    vmrun deleteVM "${PACKER_OUTPUT_DIR}/${PACKER_VM_NAME}.vmx" || true
  else
    echo "No leftover Packer VM found. Skipping VMware cleanup."
  fi
  echo "--------------------------------------------------"
}

# Function: Batch control VMs (start, stop, status)
control_vms() {
  local ACTION=$1
  echo ">>> STEP: Executing VM batch control: ${ACTION^^}..."

  # Check if vmrun command exists
  if ! command -v vmrun &> /dev/null; then
    echo "Error: 'vmrun' command not found."
    echo "Please ensure VMware Workstation is installed and its path is in your system's PATH."
    return 1
  fi

  case "$ACTION" in
    start)
      echo ">>> Starting all VMs located under ${VMS_BASE_PATH}..."
      # Find all .vmx files in the target directory
      local vmx_files
      vmx_files=$(find "${VMS_BASE_PATH}" -mindepth 2 -maxdepth 2 -type f -name "*.vmx")

      if [ -z "$vmx_files" ]; then
        echo "Warning: No .vmx files found in '${VMS_BASE_PATH}'."
        return
      fi

      while IFS= read -r vmx_path; do
        local vm_name
        vm_name=$(basename "$(dirname "$vmx_path")")
        if vmrun list | grep -q -F "$vmx_path"; then
          echo "Info: VM '$vm_name' is already running."
        else
          echo "Starting '$vm_name'..."
          vmrun start "$vmx_path" nogui
        fi
      done <<< "$vmx_files"
      echo "--- All VM start procedures completed ---"
      ;;
    stop)
      echo ">>> Gently stopping all VMs located under ${VMS_BASE_PATH}..."
      # Get the list of running VMs, filtering for .vmx paths
      local running_vms_paths
      running_vms_paths=$(vmrun list | grep -E '\.vmx$')

      if [ -z "$running_vms_paths" ]; then
        echo "Info: No VMs are currently running."
        return
      fi

      local found_to_stop=false
      while IFS= read -r vmx_path; do
        # Check if the running VM's path is inside our target directory
        if [[ "$vmx_path" == "${VMS_BASE_PATH}"* ]]; then
          local vm_name
          vm_name=$(basename "$(dirname "$vmx_path")")
          echo "Stopping '$vm_name' (path: $vmx_path)..."
          vmrun stop "$vmx_path" soft
          found_to_stop=true
        fi
      done <<< "$running_vms_paths"

      if ! $found_to_stop; then
        echo "Info: No running VMs found within the '${VMS_BASE_PATH}' directory."
      fi
      echo "--- All targeted VM stop procedures completed ---"
      ;;
    status)
      echo ">>> Checking status of all running VMs..."
      vmrun list
      echo "--- Status check completed ---"
      ;;
    *)
      echo "Error: Invalid action '$ACTION' for control_vms function."
      return 1
      ;;
  esac
}