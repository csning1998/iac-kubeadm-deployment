#!/bin/bash

# Function: Check if Docker environment is ready on the host.
check_docker_environment() {
  echo ">>> STEP: Checking Host environment for Docker..."
  local all_installed=true

  if ! command -v docker >/dev/null 2>&1; then
    echo "#### Docker: Not installed. Please install Docker Desktop or Docker Engine."
    all_installed=false
  else
    echo "#### Docker: Installed ($(docker --version))"
  fi

  # Docker Compose is typically included with Docker Desktop but might be separate.
  if ! docker compose version >/dev/null 2>&1; then
    echo "#### Docker Compose: Not found. Please ensure it's installed and accessible."
    all_installed=false
  else
    echo "#### Docker Compose: Installed ($(docker compose version))"
  fi
  
  if ! $all_installed; then
    echo "--------------------------------------------------"
    echo "Error: Core dependencies are missing. Please install them to proceed."
    exit 1
  fi
  echo "--------------------------------------------------"
  return 0
}

# Function: Configure network setting of VMWare after environment setup
set_workstation_network() {
  # Prompt for VMware network configuration
  echo ">>> VMware Network Editor configuration is required:"
  echo "- Set vmnet8 to NAT with subnet ${VMNET8_SUBNET}/${VMNET8_NETMASK} and DHCP enabled."
  echo "- Set vmnet1 to Host-only with subnet ${VMNET1_SUBNET}/${VMNET1_NETMASK} (no DHCP)."
  read -p "Do you want to automatically configure VMware networking settings by modifying /etc/vmware/networking? (y/n): " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Configuring VMware networking settings..."
    sudo /etc/init.d/vmware stop
    # Use the variable loaded from config.sh
    echo "$VMWARE_NETWORKING_CONFIG" | sudo tee /etc/vmware/networking > /dev/null
    sudo /etc/init.d/vmware start
    echo "#### VMware networking configuration completed."
  else
    echo "#### Skipping automatic VMware networking configuration. Please configure manually using VMware Network Editor."
  fi
  echo "--------------------------------------------------"
}

# This script contains functions related to the setup of the
#  Infrastructure as Code (IaC) environment.

# Function: Check IaC environment and return status
check_iac_environment() {
  echo ">>> STEP: Checking native IaC environment..."
  local all_installed=true

  command -v packer >/dev/null 2>&1 || { echo "#### HashiCorp Packer: Not installed"; all_installed=false; }
  command -v terraform >/dev/null 2>&1 || { echo "#### HashiCorp Terraform: Not installed"; all_installed=false; }
  command -v vault >/dev/null 2>&1 || { echo "#### HashiCorp Vault: Not installed"; all_installed=false; }
  command -v ansible >/dev/null 2>&1 || { echo "#### Red Hat Ansible: Not installed"; all_installed=false; }

  # Check provider-specific tools
  if [[ "${VIRTUALIZATION_PROVIDER}" == "kvm" ]]; then
    command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "#### QEMU/KVM: Not installed or not in PATH"; all_installed=false; }
    command -v virsh >/dev/null 2>&1 || { echo "#### Libvirt Client (virsh): Not installed"; all_installed=false; }
  fi

  echo "--------------------------------------------------"
  if $all_installed; then
    echo "#### All required IaC tools for the selected provider are already installed."
    read -p "######## Do you want to reinstall them? (y/n): " reinstall_answer
    if [[ ! "$reinstall_answer" =~ ^[Yy]$ ]]; then
      echo "#### Skipping IaC environment installation."
      return 1
    fi
  else
    echo "#### Some required IaC tools are missing."
    read -p "######## Do you want to proceed with the installation? (y/n): " install_answer
    if [[ ! "$install_answer" =~ ^[Yy]$ ]]; then
      echo "#### Skipping IaC environment installation."
      return 1
    fi
  fi
  return 0
}

# Function: Setup IaC Environment for the detected OS Family
setup_iac_environment() {
  echo ">>> STEP: Setting up native IaC environment for OS Family: ${HOST_OS_FAMILY^^}..."

  if [[ "${HOST_OS_FAMILY}" == "rhel" ]]; then
    # --- RHEL / Fedora Family Setup ---
    echo "#### Installing base packages using DNF..."
    sudo dnf install -y jq openssh-clients python3 python3-pip wget gnupg whois curl

    # Install KVM/QEMU packages if the provider is KVM
    if [[ "${VIRTUALIZATION_PROVIDER}" == "kvm" ]]; then
      echo "#### Installing KVM/QEMU packages..."
      sudo dnf install -y qemu-kvm libvirt-client virt-install
      echo "#### Enabling and starting libvirt service..."
      sudo systemctl enable --now libvirtd
      # Create the required symlink for Packer, as discovered
      if [ -f /usr/libexec/qemu-kvm ] && [ ! -f /usr/bin/qemu-system-x86_64 ]; then
        echo "#### Creating symlink for qemu-system-x86_64..."
        sudo ln -s /usr/libexec/qemu-kvm /usr/bin/qemu-system-x86_64
      fi
    fi

    echo "#### Installing Ansible..."
    sudo dnf install -y ansible-core
    ansible-galaxy collection install ansible.posix

    echo "#### Installing HashiCorp Toolkits (Terraform and Packer)..."
    # Create a temporary repository file forcing the RHEL 9 version
    cat <<EOF | sudo tee /etc/yum.repos.d/temp-hashicorp.repo
[hashicorp-temp]
name=HashiCorp Stable - \$basearch
baseurl=https://rpm.releases.hashicorp.com/RHEL/9/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://rpm.releases.hashicorp.com/gpg
EOF
    # Install using the temporary repo, then clean up
    sudo dnf -y install terraform packer vault --enablerepo=hashicorp-temp --refresh
    sudo rm /etc/yum.repos.d/temp-hashicorp.repo
    sudo dnf clean all

  elif [[ "${HOST_OS_FAMILY}" == "debian" ]]; then
    # --- Debian / Ubuntu Family Setup ---
    sudo apt-get update
    echo "#### Install necessary packages/libraries..."
    sudo apt install -y jq openssh-client python3 python3-pip software-properties-common wget gnupg lsb-release whois curl

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
  echo "######## HashiCorp Packer version:"
  packer --version
  echo "######## HashiCorp Terraform version:"
  terraform --version
  echo "######## HashiCorp Vault version:"
  vault --version
  echo "######## Red Hat Ansible version:"
  ansible --version
  if [[ "${VIRTUALIZATION_PROVIDER}" == "kvm" ]]; then
    qemu-system-x86_64 --version
    virsh --version
  fi

  echo "#### Native IaC environment setup and verification completed."
  echo "--------------------------------------------------"
}