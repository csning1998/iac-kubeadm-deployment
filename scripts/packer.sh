#!/bin/bash

# This script contains functions for managing the Packer image build process.

# Function: Clean up Packer output directory
cleanup_packer_output() {
  echo ">>> STEP: Cleaning Packer output directory..."
  cd "${PACKER_DIR}"

  # 1. Clean Packer Ourput directories on the host
  rm -rf "${PACKER_DIR}/output/ubuntu-server-workstation"
  rm -rf "${PACKER_DIR}/output/ubuntu-server-qemu"
  
  # 2. Clean Packer cache
  
  if [[ "${ENVIRONMENT_STRATEGY}" == "container" ]]; then
    echo "#### Cleaning Packer cache inside the container..."
    local container_user_home="/home/$(whoami)"
    local cleanup_cmd="find ${container_user_home}/.cache/packer -mindepth 1 ! -name '*.iso' -exec rm -rf {} +"
    run_command "${cleanup_cmd}" "${SCRIPT_DIR}"
  else 
    if [ -d ~/.cache/packer ]; then
      echo "#### Cleaning Packer cache, preserving ISOs..."
      find ~/.cache/packer -mindepth 1 ! -name '*.iso' -exec rm -rf {} + || true
    fi
  fi

  echo "#### Packer artifact cleanup completed."
  echo "--------------------------------------------------"
}

# Function: Execute Packer build
build_packer() {
  echo ">>> STEP: Starting new Packer build for provider: ${VIRTUALIZATION_PROVIDER^^}..."

  local cmd="packer init . && packer build \
    -var='provider=${VIRTUALIZATION_PROVIDER}' \
    -var-file=common.pkrvars.hcl \
    -var-file=secret.auto.pkrvars.hcl \
    ."

  run_command "${cmd}" "${PACKER_DIR}"

  echo "#### Packer build complete. New base image for ${VIRTUALIZATION_PROVIDER^^} is ready."
  echo "--------------------------------------------------"
}