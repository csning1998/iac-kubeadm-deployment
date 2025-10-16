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
display_vault_status
echo

PS3=">>> Please select an action: "
options=()
options+=("[ONCE-ONLY] Set up CA Certs for TLS")
options+=("[ONCE-ONLY] Initialize Vault")
options+=("[ONCE-ONLY] Generate SSH Key")
options+=("[ONCE-ONLY] Setup KVM / QEMU for Native")
options+=("[ONCE-ONLY] Setup Core IaC Tools for Native")
options+=("[ONCE-ONLY] Verify IaC Environment for Native")
options+=("Unseal Vault")
options+=("Switch Environment Strategy")
options+=("Reset Packer and Terraform")
options+=("Rebuild Packer: 02 Kubeadm Base Image")
options+=("Rebuild Packer: 03 Microk8s Base Image")
options+=("Rebuild Packer: 04 Postgres Base Image")
options+=("Rebuild Kubeadm Cluster (Packer + TF)")
options+=("Rebuild Terraform Layer 10: Kubeadm Cluster")
options+=("Rebuild Terraform Layer 10: Harbor Server")
options+=("Rebuild Terraform Layer 10: Postgres Service")
options+=("Rebuild Terraform Layer 50: Kubernetes Addons")
options+=("[DEV] Rebuild Layer 10 via Ansible Command")
options+=("Verify SSH")
options+=("Quit")
# options+=("Rebuild Terraform Layer 10: KVM Provision Only")
# options+=("Rebuild Terraform Layer 10: Ansible Bootstrapper Only")

select opt in "${options[@]}"; do
  # Record start time
  readonly START_TIME=$(date +%s)

  case $opt in
    "[ONCE-ONLY] Set up CA Certs for TLS")
      echo "# INFO: Follow the instruction below"
      generate_tls_files
      break
      ;;
    "[ONCE-ONLY] Initialize Vault")
      echo "# WARNING: This is a destructive operation for existing data."
      initialize_vault
      break
      ;;
    "[ONCE-ONLY] Generate SSH Key")
      echo "# Generate SSH Key for this project..."
      generate_ssh_key
      echo "# SSH Key successfully generated in the path '~/.ssh'."
      break
      ;;
    "[ONCE-ONLY] Setup KVM / QEMU for Native")
      echo "# Executing Setup KVM / QEMU workflow..."
      if prompt_install_libvirt_tools; then
        setup_libvirt_environment
      fi
      echo "# Setup KVM / QEMU workflow completed."
      break
      ;;
    "[ONCE-ONLY] Setup Core IaC Tools for Native")
      echo "# Executing Setup Core IaC Tools workflow..."
      if prompt_install_iac_tools; then
        setup_iac_tools
      fi
      echo "# Setup Core IaC Tools workflow completed."
      break
      ;;
    "[ONCE-ONLY] Verify IaC Environment for Native")
      verify_iac_environment
      break
      ;;
    "Unseal Vault")
      echo "# Executing standard Vault startup workflow..."
      unseal_vault
      break
      ;;
    "Switch Environment Strategy")
      switch_environment_strategy_handler
      ;;
    "Reset Packer and Terraform")
      echo "# Executing Reset All workflow..."
      purge_libvirt_resources "all"
      destroy_terraform_layer "10-provision-kubeadm"
      cleanup_packer_output "04-base-postgres"
      cleanup_packer_output "03-base-microk8s"
      cleanup_packer_output "02-base-kubeadm"
      cleanup_terraform_layer "10-provision-kubeadm"
      cleanup_terraform_layer "10-provision-harbor"
      cleanup_terraform_layer "10-provision-postgres"

      report_execution_time
      echo "# Reset All workflow completed."
      break
      ;;
    "Rebuild Packer: 02 Kubeadm Base Image")
      echo "# Executing Rebuild Packer workflow..."
      if ! check_ssh_key_exists; then break; fi
      ensure_libvirt_services_running
      cleanup_packer_output "02-base-kubeadm"
      build_packer "02-base-kubeadm"
      report_execution_time
      break
      ;;
    "Rebuild Packer: 03 Microk8s Base Image")
      echo "# Executing Rebuild Packer workflow for Microk8s Base Image..."
      if ! check_ssh_key_exists; then break; fi
      ensure_libvirt_services_running
      cleanup_packer_output "03-base-microk8s"
      build_packer "03-base-microk8s"
      report_execution_time
      break
      ;;
    "Rebuild Packer: 04 Postgres Base Image")
      echo "# Executing Rebuild Packer workflow..."
      if ! check_ssh_key_exists; then break; fi
      ensure_libvirt_services_running
      cleanup_packer_output "04-base-postgres"
      build_packer "04-base-postgres"
      report_execution_time
      break
      ;;
    "Rebuild Kubeadm Cluster (Packer + TF)")
      echo "# Executing Rebuild All workflow for Kubernetes..."
      if ! check_ssh_key_exists; then break; fi
      purge_libvirt_resources "10-provision-kubeadm"
      cleanup_packer_output "02-base-kubeadm"
      build_packer "02-base-kubeadm"
      cleanup_terraform_layer "10-provision-kubeadm"
      apply_terraform_layer "10-provision-kubeadm"
      report_execution_time
      echo "# Rebuild All workflow completed."
      break
      ;;
    "Rebuild Terraform Layer 10: Kubeadm Cluster")
      echo "# Executing Rebuild Terraform workflow for the full cluster..."
      if ! check_ssh_key_exists; then break; fi
      purge_libvirt_resources "10-provision-kubeadm"
      ensure_libvirt_services_running
      destroy_terraform_layer "10-provision-kubeadm"
      cleanup_terraform_layer "10-provision-kubeadm"
      apply_terraform_layer "10-provision-kubeadm"
      report_execution_time
      echo "# Rebuild Terraform workflow completed."
      break
      ;;
    "Rebuild Terraform Layer 10: Harbor Server")
      echo "# Executing Rebuild Terraform workflow for Harbor Server..."
      ensure_libvirt_services_running
      cleanup_terraform_layer "10-provision-harbor"
      reapply_terraform_layer "10-provision-harbor"
      report_execution_time
      echo "# Rebuild Terraform Harbor Server workflow completed."
      break
      ;;
    "Rebuild Terraform Layer 10: Postgres Service")
      echo "# Executing Rebuild Terraform workflow for Postgres Service..."
      ensure_libvirt_services_running
      cleanup_terraform_layer "10-provision-postgres"
      reapply_terraform_layer "10-provision-postgres"
      report_execution_time
      echo "# Rebuild Terraform Postgres Service workflow completed."
      break
      ;;
    "Rebuild Terraform Layer 50: Kubeadm Cluster Addons")
      echo "# Executing Rebuild Terraform workflow for Kubernetes (Kubeadm) Addons..."
      ensure_libvirt_services_running
      verify_ssh
      reapply_terraform_layer "50-provision-kubeadm-addons"
      report_execution_time
      echo "# Rebuild Terraform Kubernetes (Kubeadm) Addons workflow completed."
      break
      ;;
    "[DEV] Rebuild Layer 10 via Ansible Command")
      echo "# Executing [DEV] Rebuild via direct Ansible command..."
      if ! check_ssh_key_exists; then break; fi
      ensure_libvirt_services_running
      selector_playbook
      report_execution_time
      echo "# [DEV] Rebuild via direct Ansible command completed."
      break
      ;;
    "Verify SSH")
      echo "# Executing Verify SSH workflow..."
      if ! check_ssh_key_exists; then break; fi
      prompt_verify_ssh
      echo "# Verify SSH workflow completed."
      break
      ;;
    "Quit")
      echo "# Exiting script."
      break
      ;;
    # "Rebuild Terraform Layer 10: KVM Provision Only")
    #   echo "# Executing Rebuild Terraform workflow for KVM Provisioner only..."
    #   if ! check_ssh_key_exists; then break; fi
    #   purge_libvirt_resources
    #   ensure_libvirt_services_running
    #   destroy_terraform_layer "10-provision-kubeadm"
    #   cleanup_terraform_layer "10-provision-kubeadm"
    #   apply_terraform_layer "10-provision-kubeadm" "module.provisioner_kvm"
    #   report_execution_time
    #   echo "# Rebuild Terraform KVM Provisioner workflow completed."
    #   break
    #   ;;
    # "Rebuild Terraform Layer 10: Ansible Bootstrapper Only")
    #   echo "# Executing Rebuild Terraform workflow for Ansible Bootstrapper only..."
    #   if ! check_ssh_key_exists; then break; fi
    #   ensure_libvirt_services_running
    #   bootstrap_kubernetes_cluster
    #   report_execution_time
    #   echo "# Rebuild Terraform Ansible Bootstrapper workflow completed."
    #   break
    #   ;;
    *) echo "# Invalid option $REPLY";;
  esac
done