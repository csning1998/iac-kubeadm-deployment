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

# initialize_environment

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

# Set Terraform directory based on the selected provider
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly VMS_BASE_PATH="${TERRAFORM_DIR}/vms"
readonly USER_HOME_DIR="${HOME}"

# Main menu
echo
echo "======= IaC-Driven Virtualization Management ======="
echo
echo "Environment: ${ENVIRONMENT_STRATEGY^^}"
echo
if [[ "${ENVIRONMENT_STRATEGY}" == "container" ]]; then
  echo "Engine: ${CONTAINER_ENGINE^^}"
fi
echo

PS3=">>> Please select an action: "
options=()
options+=("Switch Environment Strategy")
if [[ "${ENVIRONMENT_STRATEGY}" == "container" ]]; then
  options+=("Switch Container Engine")
fi
options+=("Setup IaC Environment for Native")
options+=("Generate SSH Key")
options+=("Reset All")
options+=("Rebuild All")
options+=("Rebuild Packer")
options+=("Rebuild Terraform: All Stages")
options+=("Rebuild Terraform Stage I: Configure Nodes")
options+=("Rebuild Terraform Stage II: Ansible")
options+=("[DEV] Rebuild Stage II via Ansible")
options+=("Verify SSH")
options+=("Quit")

select opt in "${options[@]}"; do
  # Record start time
  readonly START_TIME=$(date +%s)

  case $opt in
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
      echo "# Setup IaC Environment workflow completed successfully."
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
      purge_libvirt_resources
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
      purge_libvirt_resources
      cleanup_packer_output
      build_packer
      reset_terraform_state
      apply_terraform_all_stages
      report_execution_time
      echo "# Rebuild All workflow completed successfully."
      break
      ;;
    "Rebuild Packer")
      echo "# Executing Rebuild Packer workflow..."
      if ! check_ssh_key_exists; then break; fi
      ensure_libvirt_services_running
      cleanup_packer_output
      build_packer
      report_execution_time
      break
      ;;
    "Rebuild Terraform: All Stages")
      echo "# Executing Rebuild Terraform workflow..."
      if ! check_ssh_key_exists; then break; fi
      purge_libvirt_resources
      ensure_libvirt_services_running
      destroy_terraform_resources
      reset_terraform_state
      apply_terraform_all_stages
      report_execution_time
      echo "# Rebuild Terraform workflow completed successfully."
      break
      ;;
    "Rebuild Terraform Stage I: Configure Nodes")
      echo "# Executing Rebuild Terraform Stage I workflow..."
      if ! check_ssh_key_exists; then break; fi
      purge_libvirt_resources
      ensure_libvirt_services_running
      destroy_terraform_resources
      reset_terraform_state
      apply_terraform_stage_I
      report_execution_time
      echo "# Rebuild Terraform Stage I workflow completed successfully."
      break
      ;;
    "Rebuild Terraform Stage II: Ansible")
      echo "# Executing Rebuild Terraform Stage II workflow..."
      if ! check_ssh_key_exists; then break; fi
      verify_ssh
      ensure_libvirt_services_running
      apply_terraform_stage_II
      report_execution_time
      echo "# Rebuild Terraform Stage II workflow completed successfully."
      break
      ;;
    "[DEV] Rebuild Stage II via Ansible")
      echo "# Executing [DEV] Rebuild Stage II via Ansible..."
      if ! check_ssh_key_exists; then break; fi
      verify_ssh
      ensure_libvirt_services_running
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
    "Quit")
      echo "# Exiting script."
      break
      ;;
    *) echo "# Invalid option $REPLY";;
  esac
done