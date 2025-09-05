#!/bin/bash

set -e -u

###
# SCRIPT INITIALIZATION AND MODULE LOADING
###

# Define base directory and load configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTS_LIB_DIR="${SCRIPT_DIR}/scripts"

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

### Set correct permissions since 

if [[ "${ENVIRONMENT_STRATEGY}" == "native" ]]; then
  echo "INFO: Switching to 'native' mode. Running pre-emptive permission check..."
  check_and_fix_permissions
  # Exit if the fix failed, preventing a switch to a broken state.
  if [ $? -ne 0 ]; then
    echo "FATAL: Permission fix failed. Aborting strategy switch." >&2
    exit 1
  fi
fi

###
# DERIVED GLOBAL VARIABLES (From Config)
###

# Set user and other readonly variables after loading configs

readonly ANSIBLE_DIR="${SCRIPT_DIR}/ansible"

# Set Terraform directory based on the selected provider
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly USER_HOME_DIR="${HOME}"

# Main menu
echo
echo "======= IaC-Driven Virtualization Management ======="
echo
echo "Environment: ${ENVIRONMENT_STRATEGY^^}"
if [[ "${ENVIRONMENT_STRATEGY}" == "container" ]]; then
  echo "Engine: PODMAN"
fi
echo

PS3=">>> Please select an action: "
options=()
options+=("Switch Environment Strategy")
options+=("Verify IaC Environment for Native")
options+=("Setup KVM / QEMU for Native")
options+=("Setup Core IaC Tools for Native")
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
    "Verify IaC Environment for Native")
      verify_iac_environment
      break
      ;;
    "Setup KVM / QEMU for Native")
      echo "# Executing Setup KVM / QEMU workflow..."
      if prompt_install_libvirt_tools; then
        setup_libvirt_environment
      fi
      echo "# Setup KVM / QEMU workflow completed successfully."
      break
      ;;
    "Setup Core IaC Tools for Native")
      echo "# Executing Setup Core IaC Tools workflow..."
      if prompt_install_iac_tools; then
        setup_iac_tools
      fi
      echo "# Setup Core IaC Tools workflow completed successfully."
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
      if ! check_vault_connection; then break; fi 
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
      if ! check_vault_connection; then break; fi 
      if ! check_ssh_key_exists; then break; fi
      ensure_libvirt_services_running
      cleanup_packer_output
      build_packer
      report_execution_time
      break
      ;;
    "Rebuild Terraform: All Stages")
      echo "# Executing Rebuild Terraform workflow..."
      if ! check_vault_connection; then break; fi 
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
      if ! check_vault_connection; then break; fi 
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
      if ! check_vault_connection; then break; fi 
      if ! check_ssh_key_exists; then break; fi
      ensure_libvirt_services_running
      apply_terraform_stage_II
      report_execution_time
      echo "# Rebuild Terraform Stage II workflow completed successfully."
      break
      ;;
    "[DEV] Rebuild Stage II via Ansible")
      echo "# Executing [DEV] Rebuild Stage II via Ansible..."
      if ! check_vault_connection; then break; fi 
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