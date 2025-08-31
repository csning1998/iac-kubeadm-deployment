# Function: Check the host operating system
check_os_details() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID_LIKE" == *"fedora"* || "$ID" == "fedora" || "$ID" == "rhel" || "$ID" == "centos" ]]; then
      export HOST_OS_FAMILY="rhel"
    elif [[ "$ID_LIKE" == *"debian"* || "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
      export HOST_OS_FAMILY="debian"
    else
      export HOST_OS_FAMILY="unknown"
    fi
    export HOST_OS_VERSION_ID="${VERSION_ID%%.*}" # Get major version
  else
    export HOST_OS_FAMILY="unknown"
    export HOST_OS_VERSION_ID="unknown"
  fi
}

# Function: Check for CPU hardware virtualization support (VT-x or AMD-V).
check_virtual_support() {
  if grep -E -q '^(vmx|svm)' /proc/cpuinfo; then
    export VIRT_SUPPORTED="true"
  else
    export VIRT_SUPPORTED="false"
  fi
}

# Function to generate the .env file with intelligent defaults if it doesn't exist.
generate_env_file() {
  if [ -f .env ]; then
    return 0 # File already exists, do nothing.
  fi

  echo ">>> .env file not found. Generating a new one with smart defaults..."

  # 1. Determine default provider based on virt support
  local default_provider="workstation"
  if [[ "${VIRT_SUPPORTED}" == "true" ]]; then
    default_provider="kvm"
  fi

  # 2. Determine default container engine based on OS family
  local default_engine="docker"
  if [[ "${HOST_OS_FAMILY}" == "rhel" ]]; then
    default_engine="podman"
  fi

  # 3. Set other defaults
  local default_strategy="container"
  local default_ssh_key="$HOME/.ssh/id_ed25519_iac_automation"

  # 4. Write the entire .env file
  cat > .env <<EOF
# --- Core Strategy Selection ---
# "kvm" or "workstation"
VIRTUALIZATION_PROVIDER="${default_provider}"

# "container" or "native"
ENVIRONMENT_STRATEGY="${default_strategy}"

# "podman" or "docker"
CONTAINER_ENGINE="${default_engine}"

# --- User and SSH Configuration ---
# Username for SSH access to the provisioned VMs.
VM_USERNAME=""

# Path to the SSH private key. This will be updated by the 'Generate SSH Key' utility.
SSH_PRIVATE_KEY="${default_ssh_key}"

# --- Container Runtime Environment ---
# These are used to map host user permissions into the container.
HOST_UID=$(id -u)
HOST_GID=$(id -g)
UNAME=$(whoami)
UHOME=${HOME}
EOF

  echo "#### .env file created successfully."
}

initialize_environment() {
  # Apply Strategic Rules Based on Detected Environment 
  echo ">>> Detected Host Environment:"
  echo "    - OS Family: ${HOST_OS_FAMILY} ${HOST_OS_VERSION_ID}"
  echo "    - Virtualization Support: ${VIRT_SUPPORTED}"
  echo "--------------------------------------------------"

  if [[ "${HOST_OS_FAMILY}" == "rhel" && "${HOST_OS_VERSION_ID}" == "10" && "${VIRT_SUPPORTED}" != "true" ]]; then
    echo "FATAL: RHEL 10 host detected, but CPU does not support hardware virtualization." >&2
    echo "       This environment is unsupported due to kernel conflicts with VMware." >&2
    exit 1
  fi
  
  # Rule 2: Any OS without virtualization must use 'workstation' as the provider.
  # This validates the config and overrides it for the current session if it's set incorrectly.
  if [[ "${VIRT_SUPPORTED}" != "true" && "${VIRTUALIZATION_PROVIDER}" != "workstation" ]]; then
    echo "WARN: CPU virtualization not supported. Forcing provider to 'workstation' for this session."
    export VIRTUALIZATION_PROVIDER="workstation" 
  fi
  
  # --- Conditionally Load Provider-Specific Configurations ---
  
  # Load VMware config only if the final, validated provider is 'workstation'.
  if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
    if [ -f "$CONFIG_VMWARE_FILE" ]; then
      # shellcheck source=scripts/config-vmware.sh
      source "$CONFIG_VMWARE_FILE"
    else
      echo "FATAL: VMware config file not found." >&2; exit 1;
    fi
  fi
}

# Function to update a specific variable in the .env file
update_env_var() {
  local key="$1"
  local value="$2"
  # This sed command finds the key and replaces its value, handling paths with slashes.
    sed -i "s|^\\(${key}\\s*=\\s*\\).*|\\1\"${value}\"|" .env
}

# Function to handle the interactive strategy switching
switch_strategy() {
  local var_name="$1"
  local new_value="$2"
  
  update_env_var "$var_name" "$new_value"
  echo
  echo "Strategy '${var_name}' in .env updated to '${new_value}'."
  ./entry.sh
}

switch_virtualization_provider_handler() {
  if [[ "${VIRT_SUPPORTED}" != "true" ]]; then
    echo "Cannot switch provider: CPU virtualization not supported. VMware is the only option."
    return
  fi
  local new_provider
  new_provider=$([[ "$VIRTUALIZATION_PROVIDER" == "workstation" ]] && echo "kvm" || echo "workstation")
  switch_strategy "VIRTUALIZATION_PROVIDER" "$new_provider"
}

switch_environment_strategy_handler() {
  local new_strategy
  new_strategy=$([[ "$ENVIRONMENT_STRATEGY" == "container" ]] && echo "native" || echo "container")
  switch_strategy "ENVIRONMENT_STRATEGY" "$new_strategy"
}

switch_container_engine_handler() {
  if [[ "${HOST_OS_FAMILY}" == "rhel" && "$CONTAINER_ENGINE" == "podman" ]]; then
      echo
      echo "WARN: You are switching to Docker on a RHEL-based host."
      echo "      This project does not manage the installation of Docker on RHEL."
      echo "      Please ensure you have manually installed Docker CE correctly before proceeding."
      read -p "      Are you sure you want to continue? (y/n): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo "      Switch cancelled."
          return
      fi
  fi
  local new_engine
  new_engine=$([[ "$CONTAINER_ENGINE" == "docker" ]] && echo "podman" || echo "docker")
  switch_strategy "CONTAINER_ENGINE" "$new_engine"
}