#!/bin/bash

# This script contains functions for managing the Packer image build process.

# Function: Clean up Packer output directory
cleanup_packer_output() {
  echo ">>> STEP: Cleaning Packer output directory..."
  cd "${PACKER_DIR}"
  if [ -d ~/.cache/packer ]; then
    echo "#### Cleaning Packer cache, preserving ISOs..."
    find ~/.cache/packer -mindepth 1 ! -name '*.iso' -exec rm -rf {} + || true
  fi
  rm -rf "${PACKER_OUTPUT_DIR}"
  echo "#### Packer output directory cleaned."
  echo "--------------------------------------------------"
}

# Function: Execute Packer build
build_packer() {
  echo ">>> STEP: Starting new Packer build..."
  cd "${PACKER_DIR}"

  docker compose run --rm iac-controller bash \
    -c "cd /app/packer && packer init . && packer build -var-file=common.pkrvars.hcl ."

  echo "#### Packer build complete. New base image (VMX) is ready."
  echo "--------------------------------------------------"
}