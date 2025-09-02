#!/bin/bash

# This script contains functions for controlling VMware Workstation VMs.

# Function: Ensure VMware services are running before executing a command.
ensure_vmware_services_running() {
  echo "#### Checking status of VMware services..."
  # Check for a key service process. If it's not running, start the services.
  if ! pgrep -f "vmware-authd" > /dev/null; then
    echo "--> VMware services appear to be stopped. Attempting to start them..."
    if sudo /etc/init.d/vmware start; then
      echo "--> VMware services started successfully."
    else
      echo "--> ERROR: Failed to start VMware services. Please check your VMware installation."
      # Exit the script if services cannot be started, as subsequent commands will fail.
      exit 1
    fi
  else
    echo "--> VMware services are already running."
  fi
}

# Function: Batch control VMs (start, stop, status)
control_terraform_vms() {
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
    delete)
      echo ">>> Deleting all VMs located under ${VMS_BASE_PATH}..."
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
        # Check if VM is running
        if vmrun list | grep -q -F "$vmx_path"; then
          echo "VM '$vm_name' is running, attempting to stop..."
          vmrun stop "$vmx_path" soft || {
            echo "Warning: Failed to stop VM '$vm_name', attempting hard stop..."
            vmrun stop "$vmx_path" hard || {
              echo "Error: Failed to stop VM '$vm_name'. Skipping deletion."
              continue
            }
          }
          echo "VM '$vm_name' stopped successfully."
        else
          echo "VM '$vm_name' is not running."
        fi

        # Delete VM from VMware inventory
        echo "Deleting VM '$vm_name' from VMware inventory..."
        vmrun deleteVM "$vmx_path" || {
          echo "Error: Failed to delete VM '$vm_name' from inventory."
          continue
        }

        # Remove VM directory
        local vm_dir
        vm_dir=$(dirname "$vmx_path")
        if [ -d "$vm_dir" ]; then
          echo "Removing VM directory: $vm_dir..."
          rm -rf "$vm_dir" || {
            echo "Error: Failed to remove VM directory '$vm_dir'."
            continue
          }
          echo "VM directory '$vm_dir' removed successfully."
        fi
      done <<< "$vmx_files"
      echo "--- All VM deletion procedures completed ---"
      ;;
    status)
      echo ">>> Checking status of all running VMs..."
      vmrun list
      echo "--- Status check completed ---"
      ;;
    *)
      echo "Error: Invalid action '$ACTION' for control_terraform_vms function."
      return 1
      ;;
  esac
}