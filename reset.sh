#!/bin/bash

set -e -u

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly PACKER_VM_NAME="ubuntu-server-24-template"

# --- Step 1: Destroy Existing Terraform Resources ---
echo ">>> STEP 1: Destroying existing Terraform-managed VMs..."
cd "${TERRAFORM_DIR}"
terraform init -upgrade
terraform destroy -auto-approve
echo "Terraform destroy complete."
echo "--------------------------------------------------"

# --- STEP 2: Cleaning up old Packer artifacts from VirtualBox ---
echo ">>> STEP 2: Cleaning up old Packer artifacts from VirtualBox..."

if VBoxManage showvminfo "$PACKER_VM_NAME" >/dev/null 2>&1; then
  echo "Found leftover Packer VM '$PACKER_VM_NAME'. Unregistering and deleting..."
  VBoxManage unregistervm "$PACKER_VM_NAME" --delete
else
  echo "No leftover Packer VM found. Skipping VirtualBox cleanup."
fi

# --- STEP 3: Cleaning output directory and starting new Packer build ---
echo ">>> STEP 3: Cleaning output directory and starting new Packer build..."
cd "${PACKER_DIR}"
rm -rf output/ubuntu-server

# --- Step 4: Deploy New VMs with Terraform ---
echo ">>> STEP 4: Initializing Terraform and applying configuration..."

cd "${TERRAFORM_DIR}"
rm -rf .terraform
rm -r .terraform.lock.hcl
rm -r terraform.tf*

echo "--------------------------------------------------"

echo "Full reset workflow completed successfully."