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
  command -v qemu-system-x86_64 >/dev/null 2>&1 || { echo "#### QEMU/KVM: Not installed or not in PATH"; all_installed=false; }
  command -v virsh >/dev/null 2>&1 || { echo "#### Libvirt Client (virsh): Not installed"; all_installed=false; }

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
    echo "#### Installing KVM/QEMU packages..."
    sudo dnf install -y qemu-kvm libvirt-client virt-install
    echo "#### Enabling and starting libvirt service..."
    sudo systemctl enable --now libvirtd
    # Create the required symlink for Packer, as discovered
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

    echo "#### Installing KVM/QEMU packages for Debian/Ubuntu..."
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
    echo "#### The script will perform the following actions in 5 steps:"
    echo "####   1. Stop conflicting services (VMware) and prepare for reconfiguration."
    echo "####   2. Apply all file-based configurations for Libvirt and QEMU."
    echo "####      (Service mode, permissions, user settings, AppArmor, bridge, etc.)"
    echo "####   3. Restart the Libvirt service to apply new settings."
    echo "####   4. Perform a final service restart to ensure stability."
    echo
    read -p "#### Do you want to proceed with these automated changes? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      echo "#### Proceeding with KVM configuration fixes..."

      # Stop all services first to ensure a clean state for configuration
      echo "--> (1/4) Stopping services for reconfiguration..."
      sudo /etc/init.d/vmware stop >/dev/null 2>&1 || true
      sudo systemctl stop libvirtd.service >/dev/null 2>&1 || true
      sudo systemctl stop libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket >/dev/null 2>&1 || true

      # Apply all file-based configurations while services are stopped
      echo "--> (2/4) Applying file-based configurations..."
      sudo systemctl disable libvirtd.socket libvirtd-ro.socket libvirtd-admin.socket >/dev/null 2>&1 || true
      
      # libvirtd.conf
      sudo sed -i 's/#unix_sock_group = "libvirt"/unix_sock_group = "libvirt"/' /etc/libvirt/libvirtd.conf
      sudo sed -i 's/#unix_sock_rw_perms = "0770"/unix_sock_rw_perms = "0770"/' /etc/libvirt/libvirtd.conf

      # qemu.conf
      sudo sed -i "s/^#*user = .*/user = \"$(whoami)\"/" /etc/libvirt/qemu.conf
      sudo sed -i "s/^#*group = .*/group = \"$(whoami)\"/" /etc/libvirt/qemu.conf
      if sudo grep -q "^#*security_driver" /etc/libvirt/qemu.conf; then
        sudo sed -i 's/^#*security_driver = .*/security_driver = "none"/g' /etc/libvirt/qemu.conf
      else
        echo 'security_driver = "none"' | sudo tee -a /etc/libvirt/qemu.conf >/dev/null
      fi

      # bridge.conf
      sudo mkdir -p /etc/qemu
      echo 'allow virbr0' | sudo tee /etc/qemu/bridge.conf >/dev/null

      # qemu-bridge-helper permissions
      if [ -f /usr/lib/qemu/qemu-bridge-helper ]; then
        sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper
      fi

      # Enable and restart the service with all new configurations applied
      echo "--> (3/4) Enabling and restarting libvirtd service..."
      sudo systemctl enable libvirtd.service >/dev/null 2>&1
      sudo systemctl restart libvirtd.service
      sleep 2 # Give the socket a moment to be created

      # Now that the service is running, perform virsh commands
      # echo "--> (4/5) Ensuring 'iac-kubeadm' storage pool is active..."
      # sudo virsh pool-info iac-kubeadm >/dev/null 2>&1 || ( \
      #   sudo virsh pool-define-as iac-kubeadm dir --target /var/lib/libvirt/images >/dev/null && \
      #   sudo virsh pool-build iac-kubeadm >/dev/null \
      # )
      # sudo virsh pool-start iac-kubeadm >/dev/null 2>&1 || true
      # sudo virsh pool-autostart iac-kubeadm >/dev/null
      
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
  qemu-system-x86_64 --version
  virsh --version

  echo "#### Native IaC environment setup and verification completed."
  echo "--------------------------------------------------"
}