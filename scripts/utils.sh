#!/bin/bash

### This script contains general utility and helper functions.

# Function: Execute a command string based on the selected strategy.
run_command() {
  local cmd_string="$1"
  local host_work_dir="$2" # Optional working directory for native mode

  if [[ "${EXECUTION_STRATEGY}" == "docker" ]]; then

    check_docker_environment

    # Ensure the controller service is running.
    if ! docker ps -q --filter "name=iac-controller" | grep -q .; then
      echo ">>> Starting iac-controller service..."
      docker compose up -d
    fi

    # Execute the command within the container which working dir is /app.
    local container_work_dir="${host_work_dir/#$SCRIPT_DIR//app}"
    docker compose exec iac-controller bash -c "cd \"${container_work_dir}\" && ${cmd_string}"

  else
    # Native Mode: Execute the command directly on the host.
    (cd "${host_work_dir}" && eval "${cmd_string}")
  fi
}

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
