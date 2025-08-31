#!/bin/bash

### This script contains general utility and helper functions.

# Function: Execute a command string based on the selected strategy.
run_command() {
  local cmd_string="$1"
  local host_work_dir="$2" # Optional working directory for native mode

  if [[ "${ENVIRONMENT_STRATEGY}" == "container" ]]; then

    # --- Containerized Execution Path ---
    local compose_cmd=""
    local compose_file=""
    local container_name=""
    local service_name="iac-controller" # The service name is consistent across all compose files

    # 1. Determine the container engine and compose file
    
    if [[ "${CONTAINER_ENGINE}" == "docker" ]]; then
      compose_cmd="docker compose"
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        compose_file="docker-compose-workstation.yml"
        container_name="iac-controller"
      else # kvm
        compose_file="docker-compose-qemu.yml"
        container_name="iac-controller-qemu"
      fi
    elif [[ "${CONTAINER_ENGINE}" == "podman" ]]; then
      # Assumes podman-compose is installed or podman compose is available.
      # Using podman-compose for broader compatibility for now.
      compose_cmd="podman compose" 
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        compose_file="podman-compose-workstation.yml"
        container_name="iac-controller"
      else # kvm
        compose_file="podman-compose-qemu.yml"
        container_name="iac-controller-qemu"
      fi
    else
      echo "FATAL: Invalid CONTAINER_ENGINE: '${CONTAINER_ENGINE}'" >&2
      exit 1
    fi

    # 2. Check if the required engine is installed
    if ! command -v "${compose_cmd%% *}" >/dev/null 2>&1; then
      echo "FATAL: Container engine '${CONTAINER_ENGINE}' not found. Please install it to proceed." >&2
      exit 1
    fi

    # 3. Ensure the compose file exists
    if [ ! -f "${SCRIPT_DIR}/${compose_file}" ]; then
      echo "FATAL: Required compose file '${compose_file}' not found in project root." >&2
      exit 1
    fi

    # 4. Ensure the controller service is running.
    if ! "${compose_cmd%% *}" ps -q --filter "name=${container_name}" | grep -q .; then
      echo ">>> Starting container service '${container_name}' using ${compose_file}..."
      (cd "${SCRIPT_DIR}" && ${compose_cmd} -f "${compose_file}" up -d)
    fi

    # 5. Execute the command within the container.
    # The working directory inside the container is always /app.
    # Map the host path to the container's /app path.
    local container_work_dir="${host_work_dir/#$SCRIPT_DIR//app}"
    echo "INFO: Executing command in container '${container_name}'..."
    (cd "${SCRIPT_DIR}" && ${compose_cmd} -f "${compose_file}" exec "${service_name}" bash -c "cd \"${container_work_dir}\" && ${cmd_string}")

  else
    # Native Mode: Execute the command directly on the host. 
    check_iac_environment
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
