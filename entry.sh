#!/bin/bash

set -e -u

# Define global variables
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly PACKER_VM_NAME="ubuntu-server-24-template"
readonly PACKER_OUTPUT_DIR="${PACKER_DIR}/output/ubuntu-server"

# Function: Purge inaccessible VirtualBox hard disks
purge_vbox_hdds() {
  echo ">>> STEP: Purging all inaccessible VirtualBox hard disks..."
  VBoxManage list hdds | awk -v RS= '/inaccessible/ {print $2}' | while read -r uuid; do
    echo "Removing inaccessible HDD with UUID: $uuid"
    VBoxManage closemedium disk "$uuid" --delete || echo "Warning: Failed to remove medium $uuid. It might already be gone."
  done
  echo "VirtualBox media registry cleaned."
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

# Function: Clean up Packer artifacts
cleanup_packer_artifacts() {
  echo ">>> STEP: Cleaning up old Packer artifacts from VirtualBox..."
  if VBoxManage showvminfo "$PACKER_VM_NAME" >/dev/null 2>&1; then
    echo "Found leftover Packer VM '$PACKER_VM_NAME'. Unregistering and deleting..."
    VBoxManage unregistervm "$PACKER_VM_NAME" --delete
  else
    echo "No leftover Packer VM found. Skipping VirtualBox cleanup."
  fi
  echo "--------------------------------------------------"
}

# Function: Clean up Packer output directory
cleanup_packer_output() {
  echo ">>> STEP: Cleaning output directory..."
  cd "${PACKER_DIR}"
  find ~/.cache/packer -mindepth 1 ! -name '*.iso' -exec rm -rf {} +
  rm -rf output/ubuntu-server
  echo "--------------------------------------------------"
}

# Function: Execute Packer build
build_packer() {
  echo ">>> STEP: Starting new Packer build..."
  cd "${PACKER_DIR}"
  packer build .
  echo "Packer build complete. New base image is ready."
  echo "--------------------------------------------------"
}

# Function: Unpack OVA file
unpack_ova() {
  echo ">>> STEP: Unpacking OVA to bypass provider bug..."
  cd "${PACKER_OUTPUT_DIR}"
  shopt -s nullglob
  ova_files=(./*.ova)
  shopt -u nullglob
  if [ ${#ova_files[@]} -ne 1 ]; then
    echo "Error: Expected exactly one OVA file in ${PACKER_OUTPUT_DIR}, but found ${#ova_files[@]}." >&2
    exit 1
  fi
  tar -xvf "${ova_files[0]}"
  echo "Unpacking complete. .ovf and .vmdk are now available."
  cd "${SCRIPT_DIR}"
  echo "--------------------------------------------------"
}

# Function: Reset Terraform state
reset_terraform_state() {
  echo ">>> STEP: Resetting Terraform state..."
  cd "${TERRAFORM_DIR}"
  rm -rf ~/.terraform/virtualbox
  rm -rf .terraform
  rm -f .terraform.lock.hcl
  rm -f terraform.tfstate
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
  echo ">>> STEP: Pruning and reconfiguring SSH connection..."
  start_ip=101
  end_ip=103
  user=$(whoami)
  known_hosts_file="/home/$user/.ssh/known_hosts"

  for ip in $(seq $start_ip $end_ip); do
    host="192.168.56.$ip"
    echo "Processing host: $host"
    if [ -f "$known_hosts_file" ]; then
      echo "Removing old keys for $host from $known_hosts_file..."
      ssh-keygen -f "$known_hosts_file" -R "$host"
    else
      echo "known_hosts file does not exist: $known_hosts_file"
    fi
    echo "Connecting to $host via SSH and executing command..."
    ssh "$user@$host" "ip a show enp0s8 | grep 'inet ' && hostname" || echo "Failed to connect to $host or command execution failed."
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
echo "VirtualBox VM Management Script"
PS3="Please select an action: "
options=("Reset All" "Rebuild All" "Rebuild Terraform" "Verify SSH" "Quit")
select opt in "${options[@]}"; do
  case $opt in
    "Reset All")
      echo "Executing Reset All workflow..."
      purge_vbox_hdds
      destroy_terraform_resources
      cleanup_packer_artifacts
      cleanup_packer_output
      reset_terraform_state
      echo "Reset All workflow completed successfully."
      break
      ;;
    "Rebuild All")
      echo "Executing Rebuild All workflow..."
      purge_vbox_hdds
      destroy_terraform_resources
      cleanup_packer_artifacts
      cleanup_packer_output
      build_packer
      unpack_ova
      reset_terraform_state
      apply_terraform
      prompt_verify_ssh
      echo "Rebuild All workflow completed successfully."
      break
      ;;
    "Rebuild Terraform")
      echo "Executing Rebuild Terraform workflow..."
      purge_vbox_hdds
      destroy_terraform_resources
      cleanup_packer_artifacts
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