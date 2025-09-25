#!/bin/bash

# This script contains functions for managing the Packer image build process.

# Function: Clean up Packer output directory and related artifacts
cleanup_packer_output() {
  echo ">>> STEP: Cleaning Packer artifacts..."

  # --- Provider-Specific Cleanup ---
  # With keep_registered = false, Packer handles unregistering the VM.
  # We only need to delete the output directory from the filesystem.

  local layer_name="$1"
  if [ -z "$layer_name" ]; then
    echo "FATAL: No Packer layer specified for build_packer function." >&2
    return 1
  fi

  rm -rf "${PACKER_DIR}/output/${layer_name}"

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
# The layer_name now corresponds to the *.pkrvars.hcl file to use.
build_packer() {
  local layer_name="$1"
  if [ -z "$layer_name" ]; then
    echo "FATAL: No Packer build type specified for build_packer function." >&2
    return 1
  fi

  # Construct the path to the specific var file.
  local build_var_file="${PACKER_DIR}/${layer_name}.pkrvars.hcl"

  if [ ! -f "$build_var_file" ]; then
    echo "FATAL: Packer var file not found: ${build_var_file}" >&2
    return 1
  fi

  echo ">>> STEP: Starting new Packer build for [${layer_name}]..."

  # The command now loads the common values file first, then the specific
  # build var file, and runs from the root Packer directory.
  local cmd="packer init . && packer build \
    -var-file=values.pkrvars.hcl \
    -var-file=${layer_name}.pkrvars.hcl \
    ."

  # Add this to abort and debug if packer build failed.
  # -on-error=abort \

  run_command "${cmd}" "${PACKER_DIR}"

  echo "#### Packer build complete. New base image for [${layer_name}] is ready."
  echo "--------------------------------------------------"
}