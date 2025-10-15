#!/bin/bash

### This script contains general utility and helper functions.

# Function: Execute a command string based on the selected strategy.
run_command() {
  local cmd_string="$1"
  local host_work_dir="$2" # Optional working directory for native mode

  if [[ "${ENVIRONMENT_STRATEGY}" == "container" ]]; then

    # --- Containerized Execution Path ---
    local compose_cmd="sudo podman compose"
    local compose_file="compose.yml"
    local container_name="iac-controller-qemu"
    local engine_cmd="sudo podman"
    local service_name="iac-controller"

    # 1. Check if Podman is installed
    if ! command -v podman >/dev/null 2>&1; then
      echo "FATAL: Container engine command 'podman' not found. Please install it to proceed." >&2
      exit 1
    fi

    # 2. Check if the required engine is installed
    if ! command -v "${engine_cmd##* }" >/dev/null 2>&1; then
      echo "FATAL: Container engine command '${engine_cmd##* }' not found. Please install it to proceed." >&2
      exit 1
    fi

    # 3. Ensure the controller service is running.
    if ! ${engine_cmd} ps -q --filter "name=${container_name}" | grep -q .; then
      echo ">>> Starting container service '${container_name}' using ${compose_file}..."
      (cd "${SCRIPT_DIR}" && ${compose_cmd} -f "${compose_file}" up -d)
    fi

    # 4. Execute the command within the container.
    # The working directory inside the container is always /app.
    # Map the host path to the container's /app path.
    local container_work_dir="${host_work_dir/#$SCRIPT_DIR//app}"
    echo "INFO: Executing command in container '${container_name}'..."
    (cd "${SCRIPT_DIR}" && ${compose_cmd} -f "${compose_file}" exec \
      -e "VAULT_ADDR=${VAULT_ADDR}" \
      -e "VAULT_CACERT=${VAULT_CACERT_PODMAN}" \
      -e "VAULT_TOKEN=${VAULT_TOKEN}" \
      "${service_name}" bash -c "cd \"${container_work_dir}\" && ${cmd_string}")
  else
    # Native Mode: Execute the command directly on the host. 
    (cd "${host_work_dir}" && eval "${cmd_string}")
  fi
}

check_and_fix_permissions() {
  # --- 1. Identify User and Project Root Directory ---
  local current_user

  current_user=$(whoami)

  # --- 2. Define Directories for Permission Check ---
  local directories_to_check=(
    "${SCRIPT_DIR}"
    "${HOME}/.cache/packer"
    "${HOME}/.ssh"
  )

  echo "INFO: Checking directory ownership for user '${current_user}'."
  
  local needs_fix=false
  local return_code=0

  # --- 3. Iterate, Check, and Correct Ownership ---
  for dir in "${directories_to_check[@]}"; do
    if [ ! -d "${dir}" ]; then
      echo "INFO: Skipping non-existent directory: ${dir}"
      continue
    fi

    # Efficiently find the first file/directory not owned by the current user.
    local incorrect_owner_path
    incorrect_owner_path=$(find "${dir}" -not -user "${current_user}" -print -quit)

    if [ -n "${incorrect_owner_path}" ]; then
      needs_fix=true
      echo "WARN: Incorrect ownership detected in '${dir}'."
      echo "      Example path with incorrect owner: ${incorrect_owner_path}"
      
      # Attempt to fix ownership.
      local fix_cmd="sudo chown -R ${current_user}:${current_user} ${dir}"
      echo ">>> Executing: ${fix_cmd}"
      
      if eval "${fix_cmd}"; then
        echo "INFO: Successfully corrected ownership for '${dir}'."
      else
        echo "FATAL: Failed to correct ownership for '${dir}'. Please check sudo permissions." >&2
        return_code=1 # Mark that a failure occurred
      fi
    else
      echo "INFO: Ownership verified for '${dir}'."
    fi
  done

  # --- 4. Final Status Report ---
  if ! ${needs_fix}; then
    echo "INFO: All checked directories have correct ownership."
  else
    if [ "${return_code}" -eq 0 ]; then
      echo "INFO: Permission check and correction process completed successfully."
    else
      echo "ERROR: The permission fix process encountered one or more errors." >&2
    fi
  fi

  return ${return_code}
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
