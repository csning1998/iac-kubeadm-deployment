#!/bin/bash

# This script contains functions for managing Terraform resources.

readonly layer_10="layers/10-cluster-provision"
readonly layer_20="layers/20-k8s-addons"
readonly layer_30="layers/30-registry-provision"

# Function: Reset Terraform state
reset_terraform_state() {
  echo ">>> STEP: Resetting Terraform state..."
  (cd "${TERRAFORM_DIR}/${layer_10}" && rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup)
  rm -rf "$HOME/.ssh/iac-kubeadm-deployment_config"
  echo "#### Terraform state reset."
  echo "--------------------------------------------------"
}

# Function: Destroy Terraform resources
destroy_terraform_resources() {
  echo ">>> STEP: Destroying existing Terraform-managed VMs..."

  local cmd="terraform init -upgrade && terraform destroy -auto-approve -lock=false -var-file=./terraform.tfvars"
  run_command "${cmd}" "${TERRAFORM_DIR}/${layer_10}"

  echo "#### Terraform destroy complete."
  echo "--------------------------------------------------"
}

### The three functions below needs further refactor.

# Function: Provision guest VMs using KVM
apply_terraform_11-provisioner_kvm() {
  echo ">>> STEP: Initializing Terraform and provision guest VMs using KVM..."
  echo ">>> Stage I: Applying VM creation..."

  local cmd="terraform init && terraform validate && terraform apply -auto-approve -var-file=./terraform.tfvars -target=module.provisioner_kvm"
  run_command "${cmd}" "${TERRAFORM_DIR}/${layer_10}"
  echo "#### VM creation and SSH configuration complete."
  echo "--------------------------------------------------"
}

# Function: Bootstrapping a Kubernetes cluster
apply_terraform_12-bootstrapper-ansible() {
  set -o pipefail
  echo ">>> Stage II: Applying Ansible Bootstrapper on cluster..."

  local cmd="terraform init && terraform validate && terraform apply -auto-approve -var-file=./terraform.tfvars -target=module.bootstrapper_ansible"
  run_command "${cmd}" "${TERRAFORM_DIR}/${layer_10}"

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

# Function: Perform Kubernetes cluster provision
apply_terraform_10-cluster-provision() {
  echo ">>> STEP: Initializing Terraform and perform Kubernetes cluster provision..."

  local cmd="terraform init && terraform validate && terraform apply -auto-approve -var-file=./terraform.tfvars"
  (cd "${TERRAFORM_DIR}" && rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup)
  run_command "${cmd}" "${TERRAFORM_DIR}/${layer_10}"

  echo "#### Full Terraform apply complete."
  echo "--------------------------------------------------"
}

# Function: Provision Add-ons for Kubernetes cluster
apply_terraform_20-k8s-addons() {
  echo ">>> STEP: Initializing Terraform and applying Kubernetes Cluster Add-ons..."

  local cmd="terraform init -upgrade && terraform destroy -auto-approve && terraform init -upgrade && terraform apply -auto-approve"
  run_command "${cmd}" "${TERRAFORM_DIR}/${layer_20}"

  echo "#### Full Terraform apply complete."
  echo "--------------------------------------------------"
}

apply_terraform_30-registry-provision(){
  echo ">>> STEP: Initializing Terraform and applying registry provision..."

  local cmd="terraform init -upgrade && terraform destroy -auto-approve && terraform init -upgrade && terraform apply -auto-approve"
  run_command "${cmd}" "${TERRAFORM_DIR}/${layer_30}"

  echo "#### Full Terraform apply complete."
  echo "--------------------------------------------------"
}