#!/bin/bash

# This script contains functions for managing Terraform resources.

# Function: Reset Terraform state
reset_terraform_state() {
  echo ">>> STEP: Resetting Terraform state..."
  (cd "${TERRAFORM_DIR}" && rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup)
  rm -rf "$HOME/.ssh/iac-kubeadm-deployment_config"
  echo "#### Terraform state reset."
  echo "--------------------------------------------------"
}

# Function: Destroy Terraform resources
destroy_terraform_resources() {
  echo ">>> STEP: Destroying existing Terraform-managed VMs for provider: ${VIRTUALIZATION_PROVIDER^^}..."

  local parallelism_arg=""

  if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
    parallelism_arg="-parallelism=1"
  fi

  local cmd="terraform init -upgrade && terraform destroy ${parallelism_arg} -auto-approve -lock=false -var-file=../terraform.tfvars"
  run_command "${cmd}" "${TERRAFORM_DIR}"

  if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
    echo "#### Cleaning up Workstation VM files..."
    rm -rf "${TERRAFORM_DIR}/vms"/*
  fi

  echo "#### Terraform destroy complete."
  echo "--------------------------------------------------"
}

# Function: Deploy Terraform Stage 1
apply_terraform_stage_I() {
  echo ">>> STEP: Initializing Terraform and applying VM configuration..."
  echo ">>> Stage I: Applying VM creation for provider: ${VIRTUALIZATION_PROVIDER^^}..."

  local target_module=""
  local parallelism_arg=""
  local tf_vars="provisioner_type=${VIRTUALIZATION_PROVIDER}"

  if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
    target_module="module.provisioner_workstation"
    parallelism_arg="-parallelism=1"
  elif [[ "${VIRTUALIZATION_PROVIDER}" == "kvm" ]]; then
    target_module="module.provisioner_kvm"
  else
    echo "Error: Invalid VIRTUALIZATION_PROVIDER: '${VIRTUALIZATION_PROVIDER}'"
    return 1
  fi

  local cmd="terraform init && terraform validate && terraform apply ${parallelism_arg} -auto-approve -var-file=../terraform.tfvars -target=${target_module}"
  run_command "${cmd}" "${TERRAFORM_DIR}"
  echo "#### VM creation and SSH configuration complete."
  echo "--------------------------------------------------"
}

# Function: Deploy Terraform Stage 2
apply_terraform_stage_II() {
  set -o pipefail
  echo ">>> Stage II: Applying Ansible configuration with default parallelism..."

  local tf_vars="provisioner_type=${VIRTUALIZATION_PROVIDER}"
  local cmd="terraform init && terraform validate && terraform apply -auto-approve -var-file=../terraform.tfvars -target=module.ansible"
  run_command "${cmd}" "${TERRAFORM_DIR}"

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