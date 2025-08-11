#!/bin/bash

set -e -u

# Define Kubernetes Cluster IP Endings

IP_ENDINGS=(200 210 211 212)

### Edit `TF_VAR_vm_username` if you want to set the other username. Default is $(whoami)
TF_VAR_vm_username=${TF_VAR_vm_username:-$(whoami)}
user="$TF_VAR_vm_username"

### READONLY: DO NOT MODIFY

# Define global variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly PACKER_VM_NAME="ubuntu-server-24-template-vmware"
readonly PACKER_OUTPUT_DIR="${PACKER_DIR}/output/ubuntu-server-vmware"

# Record start time at the beginning of the script
readonly START_TIME=$(date +%s)

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
    read -p "###### Do you want to reinstall the IaC environment? (y/n): " reinstall_answer
    if [[ ! "$reinstall_answer" =~ ^[Yy]$ ]]; then
      echo "#### Skipping IaC environment installation."
      return 1
    fi
  else
    echo "#### Some IaC tools are missing or not installed."
    read -p "###### Do you want to proceed with installing the IaC environment? (y/n): " install_answer
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

  sudo apt update
  echo "#### Install necessary packages/libraries..."
  sudo apt install -y jq openssh-client python3 software-properties-common wget gnupg lsb-release

  # Install HashiCorp Toolkits (Terraform and Packer)
  echo "#### Installing HashiCorp Toolkits (Terraform and Packer)..."
  wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt install terraform packer -y
  echo "#### Terraform and Packer installation completed."

  # Install Ansible
  echo "#### Installing Ansible..."
  sudo apt install software-properties-common -y
  sudo add-apt-repository --yes --update ppa:ansible/ansible
  sudo apt install ansible -y
  echo "#### Ansible installation completed."

  # Verify installations
  echo "#### Verifying installed tools..."
  echo "###### Packer version:"
  packer --version
  echo "###### Terraform version:"
  terraform --version
  echo "###### Ansible version:"
  ansible --version
  echo "#### IaC environment setup and verification completed."
  echo "--------------------------------------------------"
}

# Function: Configure network setting of VMWare after environment setup

set_workstation_network() {
  # Prompt for VMware network configuration
  echo ">>> VMware Network Editor configuration is required:"
  echo "- Set vmnet8 to NAT with subnet 172.16.86.0/24 and DHCP enabled."
  echo "- Set vmnet1 to Host-only with subnet 172.16.134.0/24 (no DHCP)."
  read -p "Do you want to automatically configure VMware networking settings by modifying /etc/vmware/networking? (y/n): " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "Configuring VMware networking settings..."
    sudo /etc/init.d/vmware stop
    cat << EOF | sudo tee /etc/vmware/networking
VERSION=1,0
answer VNET_1_DHCP no
answer VNET_1_DISPLAY_NAME 
answer VNET_1_HOSTONLY_NETMASK 255.255.255.0
answer VNET_1_HOSTONLY_SUBNET 172.16.134.0
answer VNET_1_VIRTUAL_ADAPTER yes
answer VNET_8_DHCP yes
answer VNET_8_DHCP_CFG_HASH B7DE0620494D07D87DE131EBECBC26E55A0AFD74
answer VNET_8_DISPLAY_NAME 
answer VNET_8_HOSTONLY_NETMASK 255.255.255.0
answer VNET_8_HOSTONLY_SUBNET 172.16.86.0
answer VNET_8_NAT yes
answer VNET_8_VIRTUAL_ADAPTER yes
EOF
    sudo /etc/init.d/vmware start
    echo "#### VMware networking configuration completed."
  else
    echo "#### Skipping automatic VMware networking configuration. Please configure manually using VMware Network Editor."
  fi
  echo "--------------------------------------------------"
}

# Function: Clean up VMware Workstation VM registrations
cleanup_vmware_vms() {
  echo ">>> STEP: Cleaning up VMware Workstation VM registrations..."
  if vmrun list | grep -q "$PACKER_VM_NAME"; then
    echo "Found leftover Packer VM '$PACKER_VM_NAME'. Stopping and deleting..."
    vmrun stop "${PACKER_OUTPUT_DIR}/${PACKER_VM_NAME}.vmx" hard || true
    vmrun deleteVM "${PACKER_OUTPUT_DIR}/${PACKER_VM_NAME}.vmx" || true
  else
    echo "No leftover Packer VM found. Skipping VMware cleanup."
  fi
  echo "--------------------------------------------------"
}

# Function: Clean up Packer output directory
cleanup_packer_output() {
  echo ">>> STEP: Cleaning Packer output directory..."
  cd "${PACKER_DIR}"
  if [ -d ~/.cache/packer ]; then
    echo "#### Cleaning Packer cache, preserving ISOs..."
    find ~/.cache/packer -mindepth 1 ! -name '*.iso' -exec rm -rf {} + || true
  fi
  rm -rf "${PACKER_OUTPUT_DIR}"
  echo "#### Packer output directory cleaned."
  echo "--------------------------------------------------"
}

# Function: Execute Packer build
build_packer() {
  echo ">>> STEP: Starting new Packer build..."
  cd "${PACKER_DIR}"
  packer init .
  packer build -var-file=common.pkrvars.hcl .
  echo "#### Packer build complete. New base image (VMX) is ready."
  echo "--------------------------------------------------"
}

# Function: Reset Terraform state
reset_terraform_state() {
  echo ">>> STEP: Resetting Terraform state..."
  cd "${TERRAFORM_DIR}"
  rm -rf ~/.terraform/vmware
  rm -rf .terraform
  rm -f .terraform.lock.hcl
  rm -f terraform.tfstate
  rm -f terraform.tfstate.backup
  echo "#### Terraform state reset."
  echo "--------------------------------------------------"
}

# Function: Destroy Terraform resources
destroy_terraform_resources() {
  echo ">>> STEP: Destroying existing Terraform-managed VMs..."
  cd "${TERRAFORM_DIR}"
  terraform init -upgrade
  terraform destroy -parallelism=1 -auto-approve -lock=false
  rm -rf "${TERRAFORM_DIR}/vms"
  echo "#### Terraform destroy complete."
  echo "--------------------------------------------------"
}

# Function: Deploy Terraform Stage 1
apply_terraform_stage_1() {
  echo ">>> STEP: Initializing Terraform and applying VM configuration..."
  cd "${TERRAFORM_DIR}"
  terraform init
  terraform validate
  echo ">>> Stage 1: Applying VM creation and SSH configuration with parallelism=1..."
  terraform apply -parallelism=1 -auto-approve -var-file=terraform.tfvars -target=null_resource.configure_nodes -target=null_resource.start_all_vms -target=local_file.ssh_config
  echo "#### VM creation and SSH configuration complete."
  echo "--------------------------------------------------"
}

# Function: Deploy Terraform Stage 2
apply_terraform_stage_2() {
  echo ">>> Stage 2: Applying Ansible configuration with default parallelism..."
  cd "${TERRAFORM_DIR}"
  terraform init
  export TF_LOG=TRACE
  terraform apply -auto-approve -var-file=terraform.tfvars -target=ansible_host.nodes -target=ansible_vault.secrets -target=ansible_playbook.setup_k8s
  unset TF_LOG
  echo "#### Ansible configuration complete."
  echo "--------------------------------------------------"
}

setup_ansible_vault() {
  echo ">>> STEP: Set up Ansible Vault ..."

  # Step 1: Check if ansible-vault is installed
  vault_pass_file="${SCRIPT_DIR}/vault_pass.txt"
  vault_file="${ANSIBLE_DIR}/group_vars/vault.yml"

  # Step 2: Get vm_username from terraform.tfvars or TF_VAR_vm_username
  if ! command -v ansible-vault >/dev/null 2>&1; then
    echo "#### Error: ansible-vault is not installed. Please install ansible (e.g., pip install ansible)"
    return 1
  fi

  if [ -f "${TERRAFORM_DIR}/terraform.tfvars" ]; then
    vm_username=$(grep '^vm_username' "${TERRAFORM_DIR}/terraform.tfvars" | grep -oP '"\K[^"]+' || true)
  fi

  vm_username="${vm_username:-${TF_VAR_vm_username:-$(whoami)}}"
  if [ -z "$vm_username" ]; then
    echo "#### Error: vm_username not found in terraform.tfvars or TF_VAR_vm_username"
    return 1
  fi

  # Step 3: Create vault_pass.txt
  echo "#### Enter Ansible Vault password:"
  read -s vault_password
  echo "$vault_password" > "$vault_pass_file"
  chmod 600 "$vault_pass_file"
  echo "#### Created $vault_pass_file"

  # Step 4: Create `ansible/group_vars/vault.yml`
  mkdir -p "${ANSIBLE_DIR}/group_vars"
  echo "vault_vm_username: $vm_username" | ansible-vault encrypt --vault-password-file "$vault_pass_file" > "$vault_file"
  if [ $? -eq 0 ]; then
    echo "#### Created and encrypted $vault_file"
  else
    echo "#### Error: Failed to create $vault_file"
    return 1
  fi
  chmod 600 "$vault_file"
  echo "#### Set permissions for $vault_file"

  # Step 5: Update .gitignore
  gitignore_file="${SCRIPT_DIR}/.gitignore"
  for file in "$vault_pass_file" "$vault_file"; do
    relative_file="${file#${SCRIPT_DIR}/}"
    if ! grep -Fx "$relative_file" "$gitignore_file" >/dev/null 2>&1; then
      echo -e "\n$relative_file" >> "$gitignore_file"
      echo "#### Added $relative_file to $gitignore_file"
    fi
  done

  # Step 6: Verify vault file and prompt for confirmation
  echo -e "#### Verifying $vault_file contents:\n"
  ansible-vault view --vault-password-file "$vault_pass_file" "$vault_file"
  if [ $? -eq 0 ]; then
    echo -e "\n #### AWARE!!! Confirm if this is the expected username for Ansible working on the VMs."
    read -p "#### If not, enter 'n' to edit, or 'y' to continue (y/n): " answer
    case "$answer" in
      [Yy])
      ;;
    *)
      echo "#### Editing $vault_file..."
      ansible-vault edit --vault-password-file "$vault_pass_file" "$vault_file"
      if [ $? -eq 0 ]; then
        echo "#### Updated $vault_file. Verifying new contents:"
        ansible-vault view --vault-password-file "$vault_pass_file" "$vault_file"
      else
        echo "#### Error: Failed to edit $vault_file"
        return 1
      fi
      ;;
    esac
  else
    echo "#### Error: Failed to verify $vault_file"
    return 1
  fi

  echo "Ansible Vault setup completed successfully."
  echo "--------------------------------------------------"
}


# Function: Verify SSH connections
verify_ssh() {
  echo ">>> STEP: Pruning and reconfiguring SSH connections..."
  known_hosts_file="/home/$user/.ssh/known_hosts"
  cd "${TERRAFORM_DIR}"

  # Read host aliases and IPs from Terraform outputs
  master_details=$(terraform output -json master_details | jq -r '. | to_entries[] | "vm${split(".", .value.ip_address)[3]} \(.value.ip_address)"')
  worker_details=$(terraform output -json workers_details | jq -r '. | to_entries[] | "vm${split(".", .value.ip_address)[3]} \(.value.ip_address)"')
  all_details=$(echo -e "$master_details\n$worker_details" | grep -v '^$')

  if [ -z "$all_details" ]; then
    echo "#### Error: No hosts found in Terraform outputs (master_details or workers_details)"
    return 1
  fi

  while IFS=' ' read -r host ip; do
    echo "#### Processing host: $host ($ip)"
    if [ -f "$known_hosts_file" ]; then
      echo "###### Removing old keys for $host and $ip from $known_hosts_file..."
      ssh-keygen -f "$known_hosts_file" -R "$host" || true
      [ -n "$ip" ] && ssh-keygen -f "$known_hosts_file" -R "$ip" || true
    else
      echo "###### known_hosts file does not exist: $known_hosts_file"
    fi
    echo "#### Connecting to $host via SSH and executing command..."
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$host" "ip a show ens32 | grep 'inet ' && hostname" || echo "Failed to connect to $host or command execution failed."
    sleep 2
  done <<< "$all_details"

  echo "#### SSH verification complete."
  echo "--------------------------------------------------"
}

# Function: Check if user wants to verify SSH connections
prompt_verify_ssh() {
  read -p "#### Do you want to verify SSH connections? (y/n): " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    verify_ssh
  else
    echo "#### Skipping SSH verification."
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

# Main menu
echo "VMware Workstation VM Management Script"
PS3="Please select an action: "
options=("Setup IaC Environment" "Set up Ansible Vault" 
        "Reset All" "Rebuild All" "Rebuild Packer" "Rebuild Terraform: All Stage" 
        "Rebuild Terraform Stage 1: Configure Nodes" "Rebuild Terraform Stage 2: Ansible" 
        "Verify SSH" "Quit"
)
select opt in "${options[@]}"; do
  case $opt in
    "Setup IaC Environment")
      echo "# Executing Setup IaC Environment workflow..."
      if check_iac_environment; then
        setup_iac_environment
      fi
      check_vmware_workstation
      set_workstation_network
      report_execution_time
      echo "# Setup IaC Environment workflow completed successfully."
      break
      ;;
    "Set up Ansible Vault")
      echo "# Executing Set up Ansible Vault workflow..."
      setup_ansible_vault
      echo "# Set up Ansible Vault workflow completed successfully."
      break
      ;;
    "Reset All")
      echo "# Executing Reset All workflow..."
      check_vmware_workstation
      cleanup_vmware_vms
      destroy_terraform_resources
      cleanup_packer_output
      reset_terraform_state
      report_execution_time
      echo "# Reset All workflow completed successfully."
      break
      ;;
    "Rebuild All")
      echo "# Executing Rebuild All workflow..."
      check_vmware_workstation
      cleanup_vmware_vms
      destroy_terraform_resources
      cleanup_packer_output
      build_packer
      reset_terraform_state
      apply_terraform_stage_1
      verify_ssh
      apply_terraform_stage_2
      report_execution_time
      echo "# Rebuild All workflow completed successfully."
      break
      ;;
    "Rebuild Packer")
      echo "# Executing Rebuild Packer workflow..."
      check_vmware_workstation
      cleanup_vmware_vms
      cleanup_packer_output
      build_packer
      report_execution_time
      break
      ;;
    "Rebuild Terraform: All Stage")
      echo "# Executing Rebuild Terraform workflow..."
      check_vmware_workstation
      destroy_terraform_resources
      reset_terraform_state
      apply_terraform_stage_1
      # verify_ssh
      apply_terraform_stage_2
      report_execution_time
      echo "# Rebuild Terraform workflow completed successfully."
      break
      ;;
    "Rebuild Terraform Stage 1: Configure Nodes")
      echo "# Executing Rebuild Terraform workflow..."
      check_vmware_workstation
      destroy_terraform_resources
      reset_terraform_state
      apply_terraform_stage_1
      # verify_ssh
      report_execution_time
      echo "# Rebuild Terraform workflow completed successfully."
      break
      ;;
    "Rebuild Terraform Stage 2: Ansible")
      echo "# Executing Rebuild Terraform workflow..."
      check_vmware_workstation
      apply_terraform_stage_2
      report_execution_time
      echo "# Rebuild Terraform workflow completed successfully."
      break
      ;;
    "Verify SSH")
      echo "# Executing Verify SSH workflow..."
      prompt_verify_ssh
      echo "# Verify SSH workflow completed successfully."
      break
      ;;
    "Quit")
      echo "# Exiting script."
      break
      ;;
    *) echo "# Invalid option $REPLY";;
  esac
done