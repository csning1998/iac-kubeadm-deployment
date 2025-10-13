#!/bin/bash

# This script contains functions related to the setup of the
# Infrastructure as Code (IaC) environment.

# Function: Verify if Libvirt/KVM tools are installed (non-interactive).
verify_libvirt_tools_installed() {
  echo ">>> Verifying Libvirt/KVM environment..."
  local all_installed=true
  local tools_to_check=(
    "qemu-system-x86_64:QEMU/KVM"
    "virsh:Libvirt Client (virsh)"
  )
  for tool_entry in "${tools_to_check[@]}"; do
    local cmd="${tool_entry%%:*}"
    local name="${tool_entry#*:}"
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "#### ${name}: Installed"
    else
      echo "#### ${name}: Missing"
      all_installed=false
    fi
  done
  if $all_installed; then return 0; else return 1; fi
}

# Function: Verify if Core IaC tools are installed (non-interactive).
verify_core_iac_tools_installed() {
  echo ">>> Verifying Core IaC Tools (HashiCorp/Ansible)..."
  local all_installed=true
  local tools_to_check=(
    "packer:HashiCorp Packer"
    "terraform:HashiCorp Terraform"
    "vault:HashiCorp Vault"
    "ansible:Red Hat Ansible"
  )
  for tool_entry in "${tools_to_check[@]}"; do
    local cmd="${tool_entry%%:*}"
    local name="${tool_entry#*:}"
    if command -v "$cmd" >/dev/null 2>&1; then
      echo "#### ${name}: Installed"
    else
      echo "#### ${name}: Missing"
      all_installed=false
    fi
  done
  if $all_installed; then return 0; else return 1; fi
}


# Function: Verify all native environment tools (non-interactive).
verify_iac_environment() {
  echo ">>> STEP: Verifying full native IaC environment..."
  local libvirt_ok=true
  local iac_ok=true
  verify_libvirt_tools_installed || libvirt_ok=false
  verify_core_iac_tools_installed || iac_ok=false
  echo "--------------------------------------------------"
  if $libvirt_ok && $iac_ok; then
    echo "#### Verification successful: All required tools are installed."
    return 0
  else
    echo "#### Verification failed: Some required tools are missing."
    return 1
  fi
}

# Function: Prompt user to install Libvirt tools (interactive).
prompt_install_libvirt_tools() {
  if verify_libvirt_tools_installed; then
    read -p "######## Libvirt/KVM is already installed. Reinstall? (y/n): " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then return 1; fi
  else
    read -p "######## Libvirt/KVM is not installed. Proceed with installation? (y/n): " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then return 1; fi
  fi
  return 0
}

# Function: Prompt user to install Core IaC tools (interactive).
prompt_install_iac_tools() {
  if verify_core_iac_tools_installed; then
    read -p "######## Core IaC tools are already installed. Reinstall? (y/n): " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then return 1; fi
  else
    read -p "######## Some Core IaC tools are missing. Proceed with installation? (y/n): " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then return 1; fi
  fi
  return 0
}

# Function: Setup KVM, QEMU, and Libvirt environment
setup_libvirt_environment() {
  echo ">>> STEP: Setting up Libvirt/KVM environment for OS Family: ${HOST_OS_FAMILY^^}..."

  if [[ "${HOST_OS_FAMILY}" == "rhel" ]]; then
    # --- RHEL / Fedora Libvirt Setup ---
    echo "#### Installing KVM/QEMU packages..."
    sudo dnf install -y qemu-kvm libvirt-client virt-install
    
    echo "#### Enabling and starting libvirt service..."
    sudo systemctl enable --now libvirtd
    
    echo "#### Adding current user to 'libvirt' group..."
    sudo usermod -aG libvirt "$(whoami)"
    
    # Create the required symlink for Packer
    if [ -f /usr/libexec/qemu-kvm ] && [ ! -f /usr/bin/qemu-system-x86_64 ]; then
      echo "#### Creating symlink for qemu-system-x86_64..."
      sudo ln -s /usr/libexec/qemu-kvm /usr/bin/qemu-system-x86_64
    fi
    echo
    echo "############################################################################"
    echo "### ACTION REQUIRED: Please log out and log back in for group changes to ###"
    echo "### take effect before running Packer or Terraform for KVM.              ###"
    echo "############################################################################"
    echo

  elif [[ "${HOST_OS_FAMILY}" == "debian" ]]; then
    # --- Debian / Ubuntu Libvirt Setup ---
    echo "#### Installing KVM/QEMU packages for Debian/Ubuntu..."
    sudo apt-get update
    sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
    
    echo "#### Enabling and starting libvirt service..."
    sudo systemctl enable --now libvirtd
    
    echo "#### Adding current user to 'libvirt' and 'kvm' groups..."
    sudo adduser "$(whoami)" libvirt
    sudo adduser "$(whoami)" kvm
    
    echo
    echo "################################################################################"
    echo "###                      IMPORTANT: KVM Post-Install Setup                   ###"
    echo "################################################################################"
    echo
    echo "#### To ensure Packer and Terraform can operate correctly, several system-level"
    echo "#### configurations are required for KVM on Debian-based systems."
    echo
    read -p "#### Do you want to proceed with these automated changes? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "#### Proceeding with KVM configuration fixes..."

      # Stop all services first to ensure a clean state for configuration
      echo "--> (1/4) Stopping services for reconfiguration..."
      sudo systemctl stop libvirtd.service >/dev/null 2>&1 || true
      sudo systemctl stop libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket >/dev/null 2>&1 || true

      # Apply all file-based configurations while services are stopped
      echo "--> (2/4) Applying file-based configurations..."
      sudo systemctl disable libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket >/dev/null 2>&1 || true
      
      sudo sed -i 's/#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/' /etc/libvirt/libvirtd.conf
      sudo sed -i 's/#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/' /etc/libvirt/libvirtd.conf

      sudo sed -i "s/^#*user = .*/user = \"$(whoami)\"/" /etc/libvirt/qemu.conf
      sudo sed -i "s/^#*group = .*/group = \"$(whoami)\"/" /etc/libvirt/qemu.conf
      if sudo grep -q "^#*security_driver" /etc/libvirt/qemu.conf; then
        sudo sed -i 's/^#*security_driver = .*/security_driver = "none"/g' /etc/libvirt/qemu.conf
      else
        echo 'security_driver = "none"' | sudo tee -a /etc/libvirt/qemu.conf >/dev/null
      fi

      sudo mkdir -p /etc/qemu
      echo 'allow virbr0' | sudo tee /etc/qemu/bridge.conf >/dev/null

      if [ -f /usr/lib/qemu/qemu-bridge-helper ]; then
        sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper
      fi

      echo "--> (3/4) Enabling and restarting libvirtd service..."
      sudo systemctl enable libvirtd.service >/dev/null 2>&1
      sudo systemctl restart libvirtd.service
      sleep 2 
      
      echo "--> (4/4) Final service restart to ensure all settings are loaded..."
      sudo systemctl restart libvirtd.service
      echo
      echo "#### KVM fixes applied successfully."
      echo "################################################################################"
      echo "###    ACTION REQUIRED: Please REBOOT your system now for all changes      ###"
      echo "###    (especially user groups and libvirt settings) to take full effect.  ###"
      echo "################################################################################"
    else
      echo "#### Skipping automatic KVM configuration fixes. Packer and Terraform may fail."
    fi
  fi
  echo "#### Libvirt/KVM environment setup completed."
  echo "--------------------------------------------------"
}

# Function: Setup Core IaC Tools (Ansible, HashiCorp) for the detected OS Family
setup_iac_tools() {
  echo ">>> STEP: Setting up core IaC tools for OS Family: ${HOST_OS_FAMILY^^}..."

  if [[ "${HOST_OS_FAMILY}" == "rhel" ]]; then
    # --- RHEL / Fedora IaC Tools Setup ---
    echo "#### Installing base packages using DNF..."
    sudo dnf install -y jq openssh-clients python3 python3-pip wget gnupg whois curl

    echo "#### Installing Ansible..."
    sudo dnf install -y ansible-core
    ansible-galaxy collection install ansible.posix community.general community.docker community.kubernetes

    echo "#### Installing HashiCorp Toolkits (Terraform and Packer)..."
    cat <<EOF | sudo tee /etc/yum.repos.d/hashicorp.repo
[hashicorp]
name=HashiCorp Stable - \$basearch
baseurl=https://rpm.releases.hashicorp.com/RHEL/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://rpm.releases.hashicorp.com/gpg
EOF
    sudo dnf -y install terraform packer vault
    
  elif [[ "${HOST_OS_FAMILY}" == "debian" ]]; then
    # --- Debian / Ubuntu IaC Tools Setup ---
    echo "#### Installing base packages using APT..."
    sudo apt-get update
    sudo apt-get install -y jq openssh-client python3 python3-pip software-properties-common wget gnupg lsb-release whois curl

    echo "#### Installing HashiCorp repository and tools (Terraform and Packer)..."
    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt-get update
    sudo apt-get install terraform packer vault -y

    echo "#### Installing Ansible..."
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt-get install ansible -y
  else
    echo "FATAL: Unsupported OS family for native installation: ${HOST_OS_FAMILY}" >&2
    exit 1
  fi

  # --- Common Verification Step ---
  echo "#### Verifying installed tools..."
  verify_core_iac_tools_installed
  
  echo "#### Core IaC tools setup and verification completed."
  echo "--------------------------------------------------"
}