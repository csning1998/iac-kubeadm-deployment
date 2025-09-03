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
  cd ${SCRIPT_DIR}
  if [ -f .env ]; then
    return 0 # File already exists, do nothing.
  fi

  echo ">>> .env file not found. Generating a new one with smart defaults..."

  # 1. Determine default container engine based on OS family
  local default_engine="docker"
  if [[ "${HOST_OS_FAMILY}" == "rhel" ]]; then
    default_engine="podman"
  fi

  # 2. Set other defaults
  local default_strategy="container"
  local default_ssh_key="$HOME/.ssh/id_ed25519_iac-kubeadm-deployment"

  # 3. Get the GID of the libvirt group on the host
  local default_libvirt_gid
  if getent group libvirt >/dev/null 2>&1; then
      default_libvirt_gid=$(getent group libvirt | cut -d: -f3)
  else
      # Fallback if libvirt isn't installed yet when script first runs
      default_libvirt_gid="999" 
  fi

  # 4. Write the entire .env file
  cat > .env <<EOF
# --- Core Strategy Selection ---
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

# For Docker on Ubuntu to get the GID of the libvirt group on the host
LIBVIRT_GID=${default_libvirt_gid}
EOF

  echo "#### .env file created successfully."
}

# Function to update a specific variable in the .env file
update_env_var() {
  cd ${SCRIPT_DIR}
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
  cd ${SCRIPT_DIR} && ./entry.sh
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