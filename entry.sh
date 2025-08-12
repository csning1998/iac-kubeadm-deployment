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
readonly VMS_BASE_PATH="${TERRAFORM_DIR}/vms"

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
  echo "######## Packer version:"
  packer --version
  echo "######## Terraform version:"
  terraform --version
  echo "######## Ansible version:"
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
apply_terraform_stage_I() {
  echo ">>> STEP: Initializing Terraform and applying VM configuration..."
  cd "${TERRAFORM_DIR}"
  terraform init
  terraform validate
  echo ">>> Stage I: Applying VM creation and SSH configuration with 'parallelism = 1' ..."
  terraform apply -parallelism=1 -auto-approve -var-file=terraform.tfvars -target=module.vm
  echo "#### VM creation and SSH configuration complete."
  echo "--------------------------------------------------"
}

apply_terraform_stage_II() {
  set -o pipefail
  echo ">>> Stage II: Applying Ansible configuration with default parallelism..."
  cd "${TERRAFORM_DIR}" || exit 1 # Exit if cd fails
  terraform init
  terraform apply -auto-approve -var-file=terraform.tfvars -target=module.ansible
  
  echo "#### Saving Ansible playbook outputs to log files..."
  mkdir -p "${ANSIBLE_DIR}/logs"
  timestamp=$(date +%Y%m%d-%H%M%S)

  if ! command -v jq >/dev/null 2>&1; then   # Ensure jq is installed
    echo "######## Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
  fi

  {
    terraform output -json ansible_playbook_stdout | format_ansible_output
  } > "${ANSIBLE_DIR}/logs/${timestamp}-ansible_stdout.log" 2>/dev/null || echo "######## Warning: Failed to save ansible_stdout.log"

  {
    terraform output -json ansible_playbook_stderr | jq -r '.'
  } > "${ANSIBLE_DIR}/logs/${timestamp}-ansible_stderr.log" 2>/dev/null || echo "######## Warning: Failed to save ansible_stderr.log"
  set +o pipefail

  echo "#### Ansible playbook logs saved to ${ANSIBLE_DIR}/logs/${timestamp}-ansible_stdout.log and ${ANSIBLE_DIR}/logs/${timestamp}-ansible_stderr.log"
  echo "#### Ansible configuration complete."
  echo "--------------------------------------------------"
}

# Function: Format Ansible JSON output into a readable summary (with ONLY verbosity set to 2 )
# Generated by Google Gemini 2.5 Pro
format_ansible_output() {
  jq -r '
  # Helper to recursively parse string-encoded JSON.
  def parse_nested_json:
    walk(
      # ONLY try to parse strings that LOOK like JSON (start with { or [)
      if type == "string" and test("^\\s*(\\{|\\[)") then
        try fromjson catch . # If it looks like JSON but fails, keep the original string
      else
        . # Keep non-string or non-JSON-like strings as they are
      end
    );

  # Helper to format specific multi-line string fields into string arrays.
  def format_multiline_strings:
    (if .msg? and (.msg | type) == "string" then .msg |= split("\n") else . end) |
    (if .stdout? and (.stdout | type) == "string" then .stdout |= split("\n") else . end)
    ;

  to_entries[] | (
    .key + ":",
    (
      .value | split("\n") | .[] |
      select(test("^(TASK|PLAY RECAP|ok:|changed:|failed:)")) |
      if test(" => \\{") then
        (split(" => ")[0] + " =>"),
        (split(" => ")[1] | fromjson | parse_nested_json | format_multiline_strings)
      else
        .
      end
    ),
    ""
  )
  '
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


# Function: Verify SSH access to hosts defined in ~/.ssh/k8s_cluster_config
verify_ssh() {
  echo ">>> STEP: Performing simple SSH access check..."
  local ssh_config_file="$HOME/.ssh/k8s_cluster_config"

  if [ ! -f "$ssh_config_file" ]; then
    echo "#### Error: SSH config file not found at $ssh_config_file"
    return 1
  fi

  # Extract host aliases from the config file.
  local all_hosts
  all_hosts=$(awk '/^Host / {print $2}' "$ssh_config_file")

  if [ -z "$all_hosts" ]; then
    echo "#### Error: No hosts found in $ssh_config_file"
    return 1
  fi

  # Loop through each host and test the connection silently.
  while IFS= read -r host; do
    if [ -z "$host" ]; then continue; fi

    # Use ssh with the 'true' command for a quick, non-interactive connection test.
    # The '-n' option is CRITICAL here to prevent ssh from consuming the stdin of the while loop.
    if ssh -n \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
      "$host" true >/dev/null 2>&1; then
      # On success, print in the requested format.
      echo "######## hostname: ${host}"
    else
      # On failure, print an error message.
      echo "######## FAILED to connect to hostname: ${host}"
    fi
  done <<< "$all_hosts"

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

# Function: Batch control VMs (start, stop, status)
control_vms() {
  local ACTION=$1
  echo ">>> STEP: Executing VM batch control: ${ACTION^^}..."

  # Check if vmrun command exists
  if ! command -v vmrun &> /dev/null; then
    echo "Error: 'vmrun' command not found."
    echo "Please ensure VMware Workstation is installed and its path is in your system's PATH."
    return 1
  fi

  case "$ACTION" in
    start)
      echo ">>> Starting all VMs located under ${VMS_BASE_PATH}..."
      # Find all .vmx files in the target directory
      local vmx_files
      vmx_files=$(find "${VMS_BASE_PATH}" -mindepth 2 -maxdepth 2 -type f -name "*.vmx")

      if [ -z "$vmx_files" ]; then
        echo "Warning: No .vmx files found in '${VMS_BASE_PATH}'."
        return
      fi

      while IFS= read -r vmx_path; do
        local vm_name
        vm_name=$(basename "$(dirname "$vmx_path")")
        if vmrun list | grep -q -F "$vmx_path"; then
          echo "Info: VM '$vm_name' is already running."
        else
          echo "Starting '$vm_name'..."
          vmrun start "$vmx_path" nogui
        fi
      done <<< "$vmx_files"
      echo "--- All VM start procedures completed ---"
      ;;
    stop)
      echo ">>> Gently stopping all VMs located under ${VMS_BASE_PATH}..."
      # Get the list of running VMs, filtering for .vmx paths
      local running_vms_paths
      running_vms_paths=$(vmrun list | grep -E '\.vmx$')

      if [ -z "$running_vms_paths" ]; then
        echo "Info: No VMs are currently running."
        return
      fi

      local found_to_stop=false
      while IFS= read -r vmx_path; do
        # Check if the running VM's path is inside our target directory
        if [[ "$vmx_path" == "${VMS_BASE_PATH}"* ]]; then
          local vm_name
          vm_name=$(basename "$(dirname "$vmx_path")")
          echo "Stopping '$vm_name' (path: $vmx_path)..."
          vmrun stop "$vmx_path" soft
          found_to_stop=true
        fi
      done <<< "$running_vms_paths"

      if ! $found_to_stop; then
        echo "Info: No running VMs found within the '${VMS_BASE_PATH}' directory."
      fi
      echo "--- All targeted VM stop procedures completed ---"
      ;;
    status)
      echo ">>> Checking status of all running VMs..."
      vmrun list
      echo "--- Status check completed ---"
      ;;
    *)
      echo "Error: Invalid action '$ACTION' for control_vms function."
      return 1
      ;;
  esac
}

# Main menu
echo "VMware Workstation VM Management Script"
PS3="Please select an action: "
options=(
    "Setup IaC Environment" 
    "Set up Ansible Vault" 
    "Reset All" 
    "Rebuild All" 
    "Rebuild Packer" 
    "Rebuild Terraform: All Stage" 
    "Rebuild Terraform Stage I: Configure Nodes" 
    "Rebuild Terraform Stage II: Ansible" 
    "Verify SSH"
    "Check VM Status"
    "Start All VMs"
    "Stop All VMs"
    "Quit"
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
      apply_terraform_stage_I
      verify_ssh
      apply_terraform_stage_II
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
      apply_terraform_stage_I
      verify_ssh
      apply_terraform_stage_II
      report_execution_time
      echo "# Rebuild Terraform workflow completed successfully."
      break
      ;;
    "Rebuild Terraform Stage I: Configure Nodes")
      echo "# Executing Rebuild Terraform workflow..."
      check_vmware_workstation
      destroy_terraform_resources
      reset_terraform_state
      apply_terraform_stage_I
      verify_ssh
      report_execution_time
      echo "# Rebuild Terraform workflow completed successfully."
      break
      ;;
    "Rebuild Terraform Stage II: Ansible")
      echo "# Executing Rebuild Terraform workflow..."
      check_vmware_workstation
      apply_terraform_stage_II
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
    "Check VM Status")
      echo "# Executing Check VM Status..."
      control_vms "status"
      report_execution_time
      echo "# Check VM Status completed."
      break
      ;;
    "Start All VMs")
      echo "# Executing Start All VMs..."
      control_vms "start"
      report_execution_time
      echo "# Start All VMs completed."
      break
      ;;
    "Stop All VMs")
      echo "# Executing Stop All VMs..."
      control_vms "stop"
      report_execution_time
      echo "# Stop All VMs completed."
      break
      ;;
    "Quit")
      echo "# Exiting script."
      break
      ;;
    *) echo "# Invalid option $REPLY";;
  esac
done