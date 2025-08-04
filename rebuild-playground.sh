#!/bin/bash

set -e -u

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PACKER_DIR="${SCRIPT_DIR}/packer-playground"

# --- Step 1: Clean Packer Artifacts & Build New Playground Image ---
echo ">>> STEP 1: Cleaning old artifacts and starting new Playground build..."
cd "${PACKER_DIR}"
echo "pwd: $(pwd)"

echo "Cleaning old playground artifacts..."
rm -rf output/playground

echo "Starting Packer build for playground..."
packer build . 

echo "Packer build for playground complete. New base image is ready."
echo "--------------------------------------------------"