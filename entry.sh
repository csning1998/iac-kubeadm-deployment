#!/bin/bash

set -e -u

# Define global variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly PACKER_VM_NAME="vmware-ubuntu-server-24-template"
readonly PACKER_OUTPUT_DIR="${PACKER_DIR}/output/ubuntu-server-vmware"

# Function: Clean up VMware Workstation VM registrations
cleanup_vmware_vms() {
  echo ">>> STEP: Cleaning up VMware Workstation VM registrations..."
  if vmrun list | grep -q "$PACKER_VM_NAME"; then
    echo "Found leftover Packer VM '$PACKER_VM_NAME'. Stopping and deleting..."
    vmrun stop "${PACKER_OUTPUT_DIR}/${PACKER_VM_NAME}.vmx" hard || true
    vmrun delete "${PACKER_OUTPUT_DIR}/${PACKER_VM_NAME}.vmx" || true
  else
    echo "No leftover Packer VM found. Skipping VMware cleanup."
  fi
  echo "--------------------------------------------------"
}

# Function: Clean up Packer output directory
cleanup_packer_output() {
  echo ">>> STEP: Cleaning Packer output directory..."
  cd "${PACKER_DIR}"
  rm -rf "${PACKER_OUTPUT_DIR}"
  echo "Packer output directory cleaned."
  echo "--------------------------------------------------"
}

# Function: Execute Packer build
build_packer() {
  echo ">>> STEP: Starting new Packer build..."
  cd "${PACKER_DIR}"
  packer init .
  packer build -var-file=common.pkrvars.hcl .
  echo "Packer build complete. New base image (VMX) is ready."
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
  echo "Terraform state reset."
  echo "--------------------------------------------------"
}

# Function: Destroy Terraform resources
destroy_terraform_resources() {
  echo ">>> STEP: Destroying existing Terraform-managed VMs..."
  cd "${TERRAFORM_DIR}"
  terraform init -upgrade
  terraform destroy -parallelism=1 -auto-approve -lock=false
  echo "Terraform destroy complete."
  echo "--------------------------------------------------"
}

# Function: Deploy Terraform
apply_terraform() {
  echo ">>> STEP: Initializing Terraform and applying configuration..."
  cd "${TERRAFORM_DIR}"
  terraform init
  terraform apply -parallelism=1 -auto-approve
  echo "Terraform apply complete. New VMs are running."
  echo "--------------------------------------------------"
}

# Function: Verify SSH connections
verify_ssh() {
  echo ">>> STEP: Pruning and reconfiguring SSH connections..."
  user=$(whoami)
  known_hosts_file="/home/$user/.ssh/known_hosts"
  start_ip=101
  end_ip=103
  for ip in $(seq $start_ip $end_ip); do
    host="172.16.134.$ip"
    echo "Processing host: $host"
    if [ -f "$known_hosts_file" ]; then
      echo "Removing old keys for $host from $known_hosts_file..."
      ssh-keygen -f "$known_hosts_file" -R "$host"
    else
      echo "known_hosts file does not exist: $known_hosts_file"
    fi
    echo "Connecting to $host via SSH and executing command..."
    ssh -o ConnectTimeout=10 "$user@$host" "ip a show ens37 | grep 'inet ' && hostname" || echo "Failed to connect to $host or command execution failed."
  done
  echo "--------------------------------------------------"
}

# Function: Check if user wants to verify SSH connections
prompt_verify_ssh() {
  read -p "Do you want to verify SSH connections? (y/n): " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    verify_ssh
  else
    echo "Skipping SSH verification."
  fi
}

# Main menu
echo "VMware Workstation VM Management Script"
PS3="Please select an action: "
options=("Reset All" "Rebuild All" "Rebuild Packer" "Rebuild Terraform" "Verify SSH" "Quit")
select opt in "${options[@]}"; do
  case $opt in
    "Reset All")
      echo "Executing Reset All workflow..."
      cleanup_vmware_vms
      destroy_terraform_resources
      cleanup_packer_output
      reset_terraform_state
      echo "Reset All workflow completed successfully."
      break
      ;;
    "Rebuild All")
      echo "Executing Rebuild All workflow..."
      cleanup_vmware_vms
      destroy_terraform_resources
      cleanup_packer_output
      build_packer
      reset_terraform_state
      apply_terraform
      prompt_verify_ssh
      echo "Rebuild All workflow completed successfully."
      break
      ;;
    "Rebuild Packer")
      echo "Executing Rebuild Packer workflow..."
      cleanup_vmware_vms
      cleanup_packer_output
      build_packer
      break
      ;;
    "Rebuild Terraform")
      echo "Executing Rebuild Terraform workflow..."
      destroy_terraform_resources
      reset_terraform_state
      apply_terraform
      prompt_verify_ssh
      echo "Rebuild Terraform workflow completed successfully."
      break
      ;;
    "Verify SSH")
      echo "Executing Verify SSH workflow..."
      verify_ssh
      echo "Verify SSH workflow completed successfully."
      break
      ;;
    "Quit")
      echo "Exiting script."
      break
      ;;
    *) echo "Invalid option $REPLY";;
  esac
done