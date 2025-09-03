#!/bin/bash

# This script contains functions for managing the Packer image build process.

# Function: Clean up Packer output directory and related artifacts
cleanup_packer_output() {
  echo ">>> STEP: Cleaning Packer artifacts for provider: ${VIRTUALIZATION_PROVIDER^^}..."

  # --- Provider-Specific Cleanup ---
  # With keep_registered = false, Packer handles unregistering the VM.
  # We only need to delete the output directory from the filesystem.
  if [[ "${VIRTUALIZATION_PROVIDER}" == "workstation" ]]; then
    echo "#### Deleting Packer output directory for Workstation..."
    rm -rf "${PACKER_DIR}/output/ubuntu-server-workstation"

  elif [[ "${VIRTUALIZATION_PROVIDER}" == "kvm" ]]; then
    echo "#### Deleting Packer output directory for KVM..."
    rm -rf "${PACKER_DIR}/output/ubuntu-server-qemu"
  fi

  # --- Generic Packer Cache Cleanup ---
  if [ -d ~/.cache/packer ]; then
    echo "#### Cleaning Packer cache on host (preserving ISOs)..."
    # Use 'sudo' to ensure we can remove any stale lock files created by
    # previous runs, regardless of ownership or permissions.
    find ~/.cache/packer -mindepth 1 ! -name '*.iso' -print0 | sudo xargs -0 rm -rf
  fi

  echo "#### Packer artifact cleanup completed."
  echo "--------------------------------------------------"
}

# Function: Execute Packer build
build_packer() {
  echo ">>> STEP: Starting new Packer build for provider: ${VIRTUALIZATION_PROVIDER^^}..."

  local cmd="packer init . && packer build \
    -var-file=common.pkrvars.hcl \
    -var-file=secret.auto.pkrvars.hcl \
    ."
  # Add this to abort and debug if packer build failed.
  # -on-error=abort \ 

  run_command "${cmd}" "${PACKER_DIR}"

  echo "#### Packer build complete. New base image for ${VIRTUALIZATION_PROVIDER^^} is ready."
  echo "--------------------------------------------------"
}