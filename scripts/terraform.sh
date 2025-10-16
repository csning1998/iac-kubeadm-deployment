#!/bin/bash

# This script contains functions for managing Terraform resources.

# Function: Clean up a specific Terraform layer's state files.
# Parameter 1: The short name of the layer (e.g., "10-provision-kubeadm") or "all".
cleanup_terraform_layer() {
  local target_layer="$1"
  if [ -z "$target_layer" ]; then
    echo "FATAL: No Terraform layer specified for cleanup_terraform_layer function." >&2
    echo "Available layers: ${ALL_LAYERS[*]}" >&2
    return 1
  fi

  local layers_to_clean=()
  if [[ "$target_layer" == "all" ]]; then
    echo ">>> STEP: Preparing to clean all Terraform layers..."
    layers_to_clean=("${ALL_LAYERS[@]}")
  else
    layers_to_clean=("$target_layer")
  fi

  for layer_name in "${layers_to_clean[@]}"; do
    local layer_dir="${TERRAFORM_DIR}/layers/${layer_name}"

    if [[ ! -d "$layer_dir" ]]; then
      echo "Warning: Terraform layer directory not found, skipping: ${layer_dir}"
      continue
    fi

    echo ">>> STEP: Cleaning Terraform artifacts for layer [${layer_name}]..."
    rm -rf "${layer_dir}/.terraform" \
      "${layer_dir}/.terraform.lock.hcl" \
      "${layer_dir}/terraform.tfstate" \
      "${layer_dir}/terraform.tfstate.backup"

    if [[ "${layer_name}" == "10-cluster-provision" ]]; then
      rm -f "${USER_HOME_DIR}/.ssh/on-premise-gitlab-deployment_config"
      echo "#### Removed global SSH configuration for cluster."
    fi

    echo "#### Terraform artifact cleanup for [${layer_name}] completed."
    echo "--------------------------------------------------"
  done
}

# Function: Apply a Terraform configuration for a specific layer.
apply_terraform_layer() {
  local layer_name="$1"          # Parameter 1: The short name of the layer.
  local target_resource="${2:-}" # Parameter 2 (Optional): A specific resource target.

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
  local cmd="terraform init -upgrade && terraform destroy -auto-approve -var-file=./terraform.tfvars && terraform init -upgrade && terraform apply -auto-approve -var-file=./terraform.tfvars"
  if [ -n "$target_resource" ]; then
    echo "#### Targeting resource: ${target_resource}"
    cmd+=" -target=${target_resource}"
  fi

  run_command "${cmd}" "${layer_dir}"

  echo "#### Terraform apply for [${layer_name}] complete."
  echo "--------------------------------------------------"
}