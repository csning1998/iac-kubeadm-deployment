#!/bin/bash

set -e -u

###
# SCRIPT INITIALIZATION AND MODULE LOADING
###

# Define base directory and load configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_LIB_DIR="${SCRIPT_DIR}/scripts"
readonly CONFIG_FILE="${SCRIPTS_LIB_DIR}/config.sh"

# Load external configuration file from the 'scripts' directory
if [ -f "$CONFIG_FILE" ]; then
  # Sourcing the config file to load variables
  # shellcheck source=scripts/config.sh
  source "$CONFIG_FILE"
else
  echo "Error: Configuration file not found at '$CONFIG_FILE'." >&2
  echo "Please ensure 'config.sh' exists in the 'scripts' directory." >&2
  exit 1
fi

# Source all function libraries from the scripts directory
for lib in "${SCRIPTS_LIB_DIR}"/*.sh; do
  if [ -r "$lib" ]; then
    # shellcheck source=scripts/iac_setup.sh
    # shellcheck source=scripts/packer.sh
    # shellcheck source=scripts/terraform.sh
    # shellcheck source=scripts/ansible.sh
    # shellcheck source=scripts/vm_control.sh
    # shellcheck source=scripts/utils.sh
    source "$lib"
  else
    echo "Error: Cannot read function library file '$lib'." >&2
    exit 1
  fi
done

###
# DERIVED GLOBAL VARIABLES (From Config)
###

# Set user and other readonly variables after loading configs
TF_VAR_vm_username=${VM_USERNAME:-$(whoami)}
user="$TF_VAR_vm_username"

readonly ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly PACKER_OUTPUT_DIR="${PACKER_DIR}/output/${PACKER_OUTPUT_SUBDIR}"
readonly VMS_BASE_PATH="${TERRAFORM_DIR}/vms"
# Record start time
readonly START_TIME=$(date +%s)

###
# MAIN EXECUTION MENU
###

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
      verify_ssh
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