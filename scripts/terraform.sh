#!/bin/bash

# This script contains functions for managing Terraform resources.

readonly layer_1="layers/1-cluster-provision"

# Function: Reset Terraform state
reset_terraform_state() {
  echo ">>> STEP: Resetting Terraform state..."
  (cd "${TERRAFORM_DIR}/${layer_1}" && rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup)
  rm -rf "$HOME/.ssh/iac-kubeadm-deployment_config"
  echo "#### Terraform state reset."
  echo "--------------------------------------------------"
}

# Function: Destroy Terraform resources
destroy_terraform_resources() {
  echo ">>> STEP: Destroying existing Terraform-managed VMs..."

  local cmd="terraform init -upgrade && terraform destroy -auto-approve -lock=false -var-file=./terraform.tfvars"
  run_command "${cmd}" "${TERRAFORM_DIR}/${layer_1}"

  echo "#### Terraform destroy complete."
  echo "--------------------------------------------------"
}

### The three functions below needs further refactor.

# Function: Deploy Terraform Stage 1
apply_terraform_stage_I() {
  echo ">>> STEP: Initializing Terraform and applying VM configuration..."
  echo ">>> Stage I: Applying VM creation..."

  local cmd="terraform init && terraform validate && terraform apply -auto-approve -var-file=./terraform.tfvars -target=module.provisioner_kvm"
  run_command "${cmd}" "${TERRAFORM_DIR}/${layer_1}"
  echo "#### VM creation and SSH configuration complete."
  echo "--------------------------------------------------"
}

# Function: Deploy Terraform Stage 2
apply_terraform_stage_II() {
  set -o pipefail
  echo ">>> Stage II: Applying Ansible configuration with default parallelism..."

  local cmd="terraform init && terraform validate && terraform apply -auto-approve -var-file=./terraform.tfvars -target=module.ansible"
  run_command "${cmd}" "${TERRAFORM_DIR}/${layer_1}"

  echo "#### Saving Ansible playbook outputs to log files..."
  mkdir -p "${ANSIBLE_DIR}/logs"
  timestamp=$(date +%Y%m%d-%H%M%S)

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

# Function: Deploy all Terraform stages without target
apply_terraform_all_stages() {
  echo ">>> STEP: Initializing Terraform and applying ALL configurations..."

  # Command without -target to apply the entire configuration
  local cmd="terraform init && terraform validate && terraform apply -auto-approve -var-file=./terraform.tfvars"
  (cd "${TERRAFORM_DIR}" && rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup)
  run_command "${cmd}" "${TERRAFORM_DIR}/${layer_1}"

  echo "#### Full Terraform apply complete."
  echo "--------------------------------------------------"
}