#!/bin/bash

# This script contains functions for managing the Packer image build process.

# Function: Clean up Packer output directory and related artifacts
cleanup_packer_output() {
  echo ">>> STEP: Cleaning Packer artifacts..."

  # --- Provider-Specific Cleanup ---
  # With keep_registered = false, Packer handles unregistering the VM.
  # We only need to delete the output directory from the filesystem.
  rm -rf "${PACKER_DIR}/output/ubuntu-server-qemu"

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
  echo ">>> STEP: Starting new Packer build..."

  local cmd="packer init . && packer build \
    -var-file=common.pkrvars.hcl \
    ."
  # Add this to abort and debug if packer build failed.
  # -on-error=abort \ 

  run_command "${cmd}" "${PACKER_DIR}"

  echo "#### Packer build complete. New base image is ready."
  echo "--------------------------------------------------"
}