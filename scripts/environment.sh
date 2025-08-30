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

initialize_environment(){
  check_os_details
  check_virtual_support

  # 2. Load external configuration file from the 'scripts' directory
  if [ -f "$CONFIG_FILE" ]; then
    # Sourcing the config file to load variables
    # shellcheck source=scripts/config.sh
    source "$CONFIG_FILE"
  else
    echo "Error: Configuration file not found at '$CONFIG_FILE'." >&2
    echo "Please ensure 'config.sh' exists in the 'scripts' directory." >&2
    exit 1
  fi

  # 3. Apply Strategic Rules Based on Detected Environment 
  echo ">>> Detected Host Environment:"
  echo "    - OS Family: ${HOST_OS_FAMILY} ${HOST_OS_VERSION_ID}"
  echo "    - Virtualization Support: ${VIRT_SUPPORTED}"
  echo "--------------------------------------------------"

  if [[ "${HOST_OS_FAMILY}" == "rhel" ]]; then
    # RHEL/Fedora Host Rules
    if [[ "${VIRT_SUPPORTED}" == "true" ]]; then
      echo "INFO: RHEL host with virtualization support detected."
      echo "      Defaulting strategy to: QEMU/KVM + Podman."
      VIRTUALIZATION_PROVIDER="kvm"
      CONTAINER_ENGINE="podman"
    else
      # No virtualization support on RHEL family
      case "${HOST_OS_VERSION_ID}" in
        10)
          echo "FATAL: RHEL 10 host detected, but CPU does not support hardware virtualization." >&2
          echo "       This environment cannot run the project because:" >&2
          echo "       1. The QEMU/KVM provider requires hardware virtualization." >&2
          echo "       2. VMware Workstation has known kernel conflicts on RHEL 10 and is not supported." >&2
          echo "       Please use a host with hardware virtualization support, or switch to an Ubuntu/Debian host for the VMware fallback option." >&2
          exit 1
          ;;
        9)
          echo "WARN: RHEL 9 host detected, but CPU does not support hardware virtualization."
          echo "      The only possible path is VMware Workstation, which is UNSUPPORTED on RHEL hosts."
          echo "      This is a community-supported option. Use at your own risk."
          echo "      Forcing provider to VMware."
          VIRTUALIZATION_PROVIDER="workstation"
          ;;
        *)
          echo "WARN: Unsupported RHEL-based version (${HOST_OS_VERSION_ID}) without virtualization detected."
          echo "      Proceeding is not recommended and may fail."
          VIRTUALIZATION_PROVIDER="workstation" # Default to the only possible non-kvm option
          ;;
      esac
    fi
  elif [[ "${HOST_OS_FAMILY}" == "debian" ]]; then
    # Ubuntu/Debian Host Rules
    CONTAINER_ENGINE="docker" # Default container engine for Debian family
    if [[ "${VIRT_SUPPORTED}" != "true" ]]; then
      echo "WARN: Ubuntu/Debian host detected, but CPU does not support hardware virtualization."
      echo "      Forcing fallback to VMware Workstation provider."
      VIRTUALIZATION_PROVIDER="workstation"
    fi
  else
    # Unknown Host OS
    echo "FATAL: Unsupported host OS family detected: ${HOST_OS_FAMILY}" >&2
    echo "       This project is designed for RHEL-based (Fedora, RHEL) or Debian-based (Ubuntu) hosts." >&2
    exit 1
  fi


  # 4. Conditionally Load VMware Configuration
  if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
    if [ -f "$CONFIG_VMWARE_FILE" ]; then
      echo "INFO: VMware provider selected, loading VMware-specific configuration..."
      # shellcheck source=scripts/config-vmware.sh
      source "$CONFIG_VMWARE_FILE"
    else
      echo "FATAL: VMware provider is selected, but config file not found at '$CONFIG_VMWARE_FILE'." >&2
      exit 1
    fi
  fi

  export VIRTUALIZATION_PROVIDER
  export ENVIRONMENT_STRATEGY
  export CONTAINER_ENGINE
}

switch_strategy() {
  local var_name="$1"
  local current_value="$2"
  local new_value="$3"
  
  sed -i "s/${var_name}=\"${current_value}\"/${var_name}=\"${new_value}\"/" "${CONFIG_FILE}"
  echo
  echo "Strategy '${var_name}' switched to '${new_value}'. Please restart the script to apply changes."
  exit 0
}


switch_virtualization_provider_handler() {
 if [[ "${VIRT_SUPPORTED}" != "true" ]]; then
      echo "Cannot switch provider: CPU virtualization not supported. VMware is the only option."
      return
  fi
  if [[ "${HOST_OS_FAMILY}" == "rhel" ]]; then
      echo "Cannot switch provider: On RHEL hosts, only QEMU/KVM is supported."
      return
  fi
  local new_provider
  new_provider=$([[ "$VIRTUALIZATION_PROVIDER" == "workstation" ]] && echo "kvm" || echo "workstation")
  switch_strategy "VIRTUALIZATION_PROVIDER" "$VIRTUALIZATION_PROVIDER" "$new_provider"
}

switch_environment_strategy_handler() {
  local new_strategy
  new_strategy=$([[ "$ENVIRONMENT_STRATEGY" == "container" ]] && echo "native" || echo "container")
  switch_strategy "ENVIRONMENT_STRATEGY" "$ENVIRONMENT_STRATEGY" "$new_strategy"
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
  switch_strategy "CONTAINER_ENGINE" "$CONTAINER_ENGINE" "$new_engine"
}