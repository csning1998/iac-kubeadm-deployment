#!/bin/bash

# This script contains functions for managing Terraform resources.

# Function: Reset Terraform state
reset_terraform_state() {
  echo ">>> STEP: Resetting Terraform state..."
  cd "${TERRAFORM_DIR}"
  rm -rf ~/.terraform/vmware
  rm -rf .terraform
  rm -f .terraform.lock.hcl
  rm -f terraform.tfstate
  rm -f terraform.tfstate.backup
  rm -rf $HOME/.ssh/k8s_cluster_config
  echo "#### Terraform state reset."
  echo "--------------------------------------------------"
}

# Function: Destroy Terraform resources
destroy_terraform_resources() {
  echo ">>> STEP: Destroying existing Terraform-managed VMs..."
  cd "${TERRAFORM_DIR}"
  terraform init -upgrade
  terraform destroy -parallelism=1 -auto-approve -lock=false
  rm -rf "${TERRAFORM_DIR}/vms/*"
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

# Function: Deploy Terraform Stage 2
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