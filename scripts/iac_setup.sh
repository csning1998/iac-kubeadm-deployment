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
  echo ">>> STEP: Checking IaC environment..."
  local all_installed=true
  local packer_version terraform_version ansible_version

  # Check Packer
  if command -v packer >/dev/null 2>&1; then
    packer_version=$(packer --version 2>/dev/null || echo "Unknown")
    echo "#### Packer: Installed (Version: $packer_version)"
  else
    packer_version="Not installed"
    all_installed=false
    echo "#### Packer: Not installed"
  fi

  # Check Terraform
  if command -v terraform >/dev/null 2>&1; then
    terraform_version=$(terraform --version 2>/dev/null | head -n 1 || echo "Unknown")
    echo "#### Terraform: Installed (Version: $terraform_version)"
  else
    terraform_version="Not installed"
    all_installed=false
    echo "#### Terraform: Not installed"
  fi

  # Check Ansible
  if command -v ansible >/dev/null 2>&1; then
    ansible_version=$(ansible --version 2>/dev/null | head -n 1 || echo "Unknown")
    echo "#### Ansible: Installed (Version: $ansible_version)"
  else
    ansible_version="Not installed"
    all_installed=false
    echo "#### Ansible: Not installed"
  fi

  echo "--------------------------------------------------"
  if $all_installed; then
    echo "#### All required IaC tools are already installed."
    read -p "######## Do you want to reinstall the IaC environment? (y/n): " reinstall_answer
    if [[ ! "$reinstall_answer" =~ ^[Yy]$ ]]; then
      echo "#### Skipping IaC environment installation."
      return 1
    fi
  else
    echo "#### Some IaC tools are missing or not installed."
    read -p "######## Do you want to proceed with installing the IaC environment? (y/n): " install_answer
    if [[ ! "$install_answer" =~ ^[Yy]$ ]]; then
      echo "#### Skipping IaC environment installation."
      return 1
    fi
  fi
  return 0
}

# Function: Setup IaC Environment
setup_iac_environment() {
  echo ">>> STEP: Setting up IaC environment..."

  echo "Prior to executing other options, registration is required on Broadcom.com to download and install VMWare Workstation Pro 17.5+."
  echo "Link: https://support.broadcom.com/group/ecx/my-dashboard"
  echo

  read -n 1 -s -r -p "Press any key to continue..."
  echo
  
  sudo apt-get update
  echo "#### Install necessary packages/libraries..."
  sudo apt install -y jq openssh-client python3 software-properties-common wget gnupg lsb-release whois

  # Install HashiCorp Toolkits (Terraform and Packer)
  echo "#### Installing HashiCorp Toolkits (Terraform and Packer)..."
  wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get install terraform packer -y
  echo "#### Terraform and Packer installation completed."

  # Install Ansible
  echo "#### Installing Ansible..."
  sudo add-apt-repository --yes --update ppa:ansible/ansible
  sudo apt-get install ansible ansible-lint -y
  echo "#### Ansible installation completed."

  # Verify installations
  echo "#### Verifying installed tools..."
  echo "######## Packer version:"
  packer --version
  echo "######## Terraform version:"
  terraform --version
  echo "######## Ansible version:"
  ansible --version
  echo "#### IaC environment setup and verification completed."
  echo "--------------------------------------------------"
}