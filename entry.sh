#!/bin/bash

set -e -u

###
# SCRIPT INITIALIZATION AND MODULE LOADING
###

# Define base directory and load configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_LIB_DIR="${SCRIPT_DIR}/scripts"
readonly CONFIG_VMWARE_FILE="${SCRIPTS_LIB_DIR}/config-vmware.sh"

source "${SCRIPTS_LIB_DIR}/utils_environment.sh"

###
# MAIN ENVIRONMENT BOOTSTRAP LOGIC
###
check_os_details
check_virtual_support
generate_env_file

# Source the .env file to export its variables to any sub-processes
set -o allexport
source .env
set +o allexport

initialize_environment

for lib in "${SCRIPTS_LIB_DIR}"/*.sh; do
  if [[ "$lib" != *"/utils_environment.sh" ]]; then
    source "$lib"
  fi
done

###
# DERIVED GLOBAL VARIABLES (From Config)
###

# Set user and other readonly variables after loading configs

readonly ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
# readonly PACKER_OUTPUT_DIR="${PACKER_DIR}/output/${PACKER_OUTPUT_SUBDIR}"
readonly VMS_BASE_PATH="${TERRAFORM_DIR}/vms"
readonly USER_HOME_DIR="${HOME}"

# Main menu
echo
echo "======= IaC-Driven Virtualization Management ======="
echo "Provider: ${VIRTUALIZATION_PROVIDER^^} | Environment: ${ENVIRONMENT_STRATEGY^^} | Engine: ${CONTAINER_ENGINE^^}"
echo

PS3=">>> Please select an action: "
options=()
# Dynamically build the menu based on the environment
options+=("Switch Virtualization Provider")
options+=("Switch Environment Strategy")
options+=("Switch Container Engine")

options+=("Setup IaC Environment for Native")
if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
  options+=("Setup VMware Network")
fi

options+=("Generate SSH Key")
options+=("Reset All")
options+=("Rebuild All")
options+=("Rebuild Packer")
options+=("Rebuild Terraform: All Stages")
options+=("Rebuild Terraform Stage I: Configure Nodes")
options+=("Rebuild Terraform Stage II: Ansible")
options+=("[DEV] Rebuild Stage II via Ansible")
options+=("Verify SSH")
options+=("Check VM Status")
options+=("Start All VMs")
options+=("Stop All VMs")
options+=("Delete All VMs")
options+=("Quit")

select opt in "${options[@]}"; do
  # Record start time
  readonly START_TIME=$(date +%s)

  case $opt in
    "Switch Virtualization Provider")
      switch_virtualization_provider_handler
      ;;
    "Switch Environment Strategy")
      switch_environment_strategy_handler
      ;;
    "Switch Container Engine")
      switch_container_engine_handler
      ;;
    "Setup IaC Environment for Native")
      echo "# Executing Setup IaC Environment workflow..."
      if check_iac_environment; then
        setup_iac_environment
      fi
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        check_vmware_workstation
      fi
      # TODO: Add check for KVM environment
      echo "# Setup IaC Environment workflow completed successfully."
      break
      ;;
    "Setup VMware Network")
      echo "# Executing Setup VMware Network workflow..."
      check_vmware_workstation
      set_workstation_network
      report_execution_time
      echo "# Setup VMware Network workflow completed successfully."
      break
      ;;
    "Generate SSH Key")
      echo "# Generate SSH Key for this project..."
      generate_ssh_key
      echo "# SSH Key successfully generated in the path '~/.ssh'."
      break
      ;;
    "Reset All")
      echo "# Executing Reset All workflow..."
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        check_vmware_workstation
        cleanup_packer_vms
        control_terraform_vms "delete"
      fi
      # TODO: Add KVM cleanup logic
      destroy_terraform_resources
      cleanup_packer_output
      reset_terraform_state
      report_execution_time
      echo "# Reset All workflow completed successfully."
      break
      ;;
    "Rebuild All")
      echo "# Executing Rebuild All workflow..."
      if ! check_ssh_key_exists; then break; fi
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        check_vmware_workstation
        cleanup_packer_vms
        deintegrate_ssh_config # This is SSH config, likely reusable
      fi
      # TODO: Add KVM cleanup logic
      cleanup_packer_output
      build_packer
      reset_terraform_state
      apply_terraform_stage_I
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        control_terraform_vms "start"
      fi
      # TODO: Add KVM start logic
      verify_ssh
      apply_terraform_stage_II
      report_execution_time
      echo "# Rebuild All workflow completed successfully."
      break
      ;;
    "Rebuild Packer")
      echo "# Executing Rebuild Packer workflow..."
      if ! check_ssh_key_exists; then break; fi
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        check_vmware_workstation
        cleanup_packer_vms
      fi
      # TODO: Add KVM cleanup logic for packer
      cleanup_packer_output
      build_packer
      report_execution_time
      break
      ;;
    "Rebuild Terraform: All Stages")
      echo "# Executing Rebuild Terraform workflow..."
      if ! check_ssh_key_exists; then break; fi
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        check_vmware_workstation
        control_terraform_vms "delete"
      fi
      # TODO: Add KVM cleanup logic
      destroy_terraform_resources
      reset_terraform_state
      apply_terraform_stage_I
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        control_terraform_vms "start"
      fi
      # TODO: Add KVM start logic
      verify_ssh
      apply_terraform_stage_II
      report_execution_time
      echo "# Rebuild Terraform workflow completed successfully."
      break
      ;;
    "Rebuild Terraform Stage I: Configure Nodes")
      echo "# Executing Rebuild Terraform Stage I workflow..."
      if ! check_ssh_key_exists; then break; fi
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        check_vmware_workstation
        control_terraform_vms "delete"
      fi
      # TODO: Add KVM cleanup logic
      destroy_terraform_resources
      reset_terraform_state
      apply_terraform_stage_I
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        control_terraform_vms "start"
      fi
      # TODO: Add KVM start logic
      verify_ssh
      report_execution_time
      echo "# Rebuild Terraform Stage I workflow completed successfully."
      break
      ;;
    "Rebuild Terraform Stage II: Ansible")
      echo "# Executing Rebuild Terraform Stage II workflow..."
      if ! check_ssh_key_exists; then break; fi
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        control_terraform_vms "start"
      fi
      # TODO: Add KVM start logic
      verify_ssh
      apply_terraform_stage_II
      report_execution_time
      echo "# Rebuild Terraform Stage II workflow completed successfully."
      break
      ;;
    "[DEV] Rebuild Stage II via Ansible")
      echo "# Executing [DEV] Rebuild Stage II via Ansible..."
      if ! check_ssh_key_exists; then break; fi
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        control_terraform_vms "start"
      fi
      # TODO: Add KVM start logic
      verify_ssh
      apply_ansible_stage_II
      report_execution_time
      echo "# [DEV] Rebuild Stage II via Ansible completed successfully."
      break
      ;;
    "Verify SSH")
      echo "# Executing Verify SSH workflow..."
      if ! check_ssh_key_exists; then break; fi
      prompt_verify_ssh
      echo "# Verify SSH workflow completed successfully."
      break
      ;;
    "Check VM Status")
      echo "# Executing Check VM Status..."
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        control_terraform_vms "status"
      fi
      # TODO: Add KVM status check
      report_execution_time
      echo "# Check VM Status completed."
      break
      ;;
    "Start All VMs")
      echo "# Executing Start All VMs..."
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        control_terraform_vms "start"
      fi
      # TODO: Add KVM start logic
      report_execution_time
      echo "# Start All VMs completed."
      break
      ;;
    "Stop All VMs")
      echo "# Executing Stop All VMs..."
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        control_terraform_vms "stop"
      fi
      # TODO: Add KVM stop logic
      report_execution_time
      echo "# Stop All VMs completed."
      break
      ;;
    "Delete All VMs")
      echo "# Executing Deletion of All VMs..."
      if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
        control_terraform_vms "delete"
      fi
      # TODO: Add KVM delete logic
      report_execution_time
      echo "# Deletion of All VMs completed."
      break
      ;;
    "Quit")
      echo "# Exiting script."
      break
      ;;
    *) echo "# Invalid option $REPLY";;
  esac
done