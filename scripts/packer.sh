#!/bin/bash

# This script contains functions for managing the Packer image build process.

# Function: Clean up Packer output directory and related artifacts
cleanup_packer_output() {
  echo ">>> STEP: Cleaning Packer artifacts..."

  # --- Provider-Specific Cleanup ---
  # With keep_registered = false, Packer handles unregistering the VM.
  # We only need to delete the output directory from the filesystem.
  rm -rf "${PACKER_DIR}/output/10-k8s-base"
  rm -rf "${PACKER_DIR}/output/20-registry-base"

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
  
  local layer_name="$1"
  if [ -z "$layer_name" ]; then
    echo "FATAL: No Packer layer specified for build_packer function." >&2
    return 1
  fi

  local layer_dir="${PACKER_DIR}/layers/${layer_name}"
  if [ ! -d "$layer_dir" ]; then
    echo "FATAL: Packer layer directory not found: ${layer_dir}" >&2
    return 1
  fi

  echo ">>> STEP: Starting new Packer build for layer [${layer_name}]..."

  local cmd="packer init . && packer build \
    -var-file=../../values.pkrvars.hcl ."
  # Add this to abort and debug if packer build failed.
  # -on-error=abort \ 

  run_command "${cmd}" "${layer_dir}"

  echo "#### Packer build complete. New base image is ready."
  echo "--------------------------------------------------"
}