#!/bin/bash

# This script contains functions for managing Terraform resources.

# Function: Clean up a specific Terraform layer's state files.
# Parameter 1: The short name of the layer (e.g., "10-cluster-provision").
cleanup_terraform_layer() {
  local layer_name="$1"
  if [ -z "$layer_name" ]; then
    echo "FATAL: No Terraform layer specified for cleanup_terraform_layer function." >&2
    return 1
  fi

  local layer_dir="${TERRAFORM_DIR}/layers/${layer_name}"
  if [ ! -d "$layer_dir" ]; then
    echo "FATAL: Terraform layer directory not found: ${layer_dir}" >&2
    return 1
  fi

  echo ">>> STEP: Cleaning Terraform artifacts for layer [${layer_name}]..."
  rm -rf "${layer_dir}/.terraform" \
    "${layer_dir}/.terraform.lock.hcl" \
    "${layer_dir}/terraform.tfstate" \
    "${layer_dir}/terraform.tfstate.backup"

  # Clean up global state associated with the cluster if cleaning the main cluster layer.
  # This check now uses a hardcoded string, matching the requested pattern.
  if [[ "${layer_name}" == "10-cluster-provision" ]]; then
      rm -rf "${USER_HOME_DIR}/.ssh/iac-kubeadm-deployment_config"
      echo "#### Removed global SSH configuration for cluster."
  fi

  echo "#### Terraform artifact cleanup for [${layer_name}] completed."
  echo "--------------------------------------------------"
}

# Function: Destroy all resources in a specific Terraform layer.
# Parameter 1: The short name of the layer.
destroy_terraform_layer() {
  local layer_name="$1"
  if [ -z "$layer_name" ]; then
    echo "FATAL: No Terraform layer specified for destroy_terraform_layer function." >&2
    return 1
  fi

  local layer_dir="${TERRAFORM_DIR}/layers/${layer_name}"
  if [ ! -d "$layer_dir" ]; then
    echo "FATAL: Terraform layer directory not found: ${layer_dir}" >&2
    return 1
  fi

  echo ">>> STEP: Destroying resources for layer [${layer_name}]..."
  local cmd="terraform init -upgrade && terraform destroy -auto-approve -lock=false -var-file=./terraform.tfvars"
  run_command "${cmd}" "${layer_dir}"

  echo "#### Terraform destroy for [${layer_name}] complete."
  echo "--------------------------------------------------"
}

# Function: Apply a Terraform configuration for a specific layer.
# Parameter 1: The short name of the layer.
# Parameter 2 (Optional): A specific resource target.
apply_terraform_layer() {
  local layer_name="$1"
  local target_resource="${2:-}" # Optional

  if [ -z "$layer_name" ]; then
    echo "FATAL: No Terraform layer specified for apply_terraform_layer function." >&2
    return 1
  fi

  local layer_dir="${TERRAFORM_DIR}/layers/${layer_name}"
  if [ ! -d "$layer_dir" ]; then
    echo "FATAL: Terraform layer directory not found: ${layer_dir}" >&2
    return 1
  fi

  echo ">>> STEP: Applying Terraform configuration for layer [${layer_name}]..."

  local cmd="terraform init -upgrade && terraform validate && terraform apply -auto-approve -var-file=./terraform.tfvars"
  if [ -n "$target_resource" ]; then
    echo "#### Targeting resource: ${target_resource}"
    cmd+=" -target=${target_resource}"
  fi

  run_command "${cmd}" "${layer_dir}"

  echo "#### Terraform apply for [${layer_name}] complete."
  echo "--------------------------------------------------"
}

# Function: Force re-apply a layer by destroying it first.
# Parameter 1: The short name of the layer.
reapply_terraform_layer() {
  local layer_name="$1"
  if [ -z "$layer_name" ]; then
    echo "FATAL: No Terraform layer specified for reapply_terraform_layer function." >&2
    return 1
  fi

  local layer_dir="${TERRAFORM_DIR}/layers/${layer_name}"
  if [ ! -d "$layer_dir" ]; then
    echo "FATAL: Terraform layer directory not found: ${layer_dir}" >&2
    return 1
  fi

  echo ">>> STEP: Re-applying Terraform configuration for layer [${layer_name}]..."

  local cmd="terraform init -upgrade && terraform destroy -auto-approve -var-file=./terraform.tfvars && terraform apply -auto-approve -var-file=./terraform.tfvars"
  run_command "${cmd}" "${layer_dir}"

  echo "#### Terraform re-apply for [${layer_name}] complete."
  echo "--------------------------------------------------"
}

# Function: A specific workflow to bootstrap the Kubernetes cluster.
bootstrap_kubernetes_cluster() {
  echo ">>> WORKFLOW: Bootstrapping Kubernetes Cluster..."

  # The specific layer name is defined locally for this workflow.
  local cluster_layer_name="10-cluster-provision"

  # Layer I: Provision VMs.
  apply_terraform_layer "${cluster_layer_name}" "module.provisioner_kvm"

  # Layer II: Apply Ansible Bootstrapper.
  apply_terraform_layer "${cluster_layer_name}" "module.bootstrapper_ansible"

  # Post-apply logic specific to this workflow.
  echo "#### Saving Ansible playbook outputs to log files..."
  set -o pipefail
  mkdir -p "${ANSIBLE_DIR}/logs"
  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local layer_dir="${TERRAFORM_DIR}/layers/${cluster_layer_name}"

  (cd "${layer_dir}" && terraform output -json ansible_playbook_stdout | format_ansible_output) > "${ANSIBLE_DIR}/logs/${timestamp}-ansible_stdout.log" 2>/dev/null || echo "######## Warning: Failed to save ansible_stdout.log"
  (cd "${layer_dir}" && terraform output -json ansible_playbook_stderr | jq -r '.') > "${ANSIBLE_DIR}/logs/${timestamp}-ansible_stderr.log" 2>/dev/null || echo "######## Warning: Failed to save ansible_stderr.log"

  set +o pipefail
  echo "#### Ansible playbook logs saved."
  echo "--------------------------------------------------"
}