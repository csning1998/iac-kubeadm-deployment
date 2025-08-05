#!/bin/bash

set -e -u

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly PACKER_VM_NAME="ubuntu-server-24-template"

# --- STEP 0: Purging all Inaccessible VirtualBox Hard Disks ---
echo ">>> STEP 0: Purging all inaccessible VirtualBox hard disks..."
VBoxManage list hdds | awk -v RS= '/inaccessible/ {print $2}' | while read -r uuid; do
    echo "Removing inaccessible HDD with UUID: $uuid"
    VBoxManage closemedium disk "$uuid" --delete || echo "Warning: Failed to remove medium $uuid. It might already be gone."
done
echo "VirtualBox media registry cleaned."
echo "--------------------------------------------------"

# --- Step 1: Destroy Existing Terraform Resources ---
echo ">>> STEP 1: Destroying existing Terraform-managed VMs..."
cd "${TERRAFORM_DIR}"
terraform init -upgrade
terraform destroy -auto-approve -lock=false
echo "Terraform destroy complete."
echo "--------------------------------------------------"

# --- STEP 2: Cleaning up old Packer artifacts from VirtualBox ---
# This step is for cleaning up any leftover VMs from a failed Packer build, which is separate from Terraform's state.
echo ">>> STEP 2: Cleaning up old Packer artifacts from VirtualBox..."

if VBoxManage showvminfo "$PACKER_VM_NAME" >/dev/null 2>&1; then
  echo "Found leftover Packer VM '$PACKER_VM_NAME'. Unregistering and deleting..."
  VBoxManage unregistervm "$PACKER_VM_NAME" --delete
else
  echo "No leftover Packer VM found. Skipping VirtualBox cleanup."
fi
echo "--------------------------------------------------"

# --- STEP 3: Cleaning output directory and starting new Packer build ---
echo ">>> STEP 3: Cleaning output directory"
cd "${PACKER_DIR}"
find ~/.cache/packer -mindepth 1 ! -name '*.iso' -exec rm -rf {} +
rm -rf output/ubuntu-server
echo "--------------------------------------------------"

# --- Step 4: Deploy New VMs with Terraform ---
echo ">>> STEP 4: Resetting Terraform ..."

cd "${TERRAFORM_DIR}"
rm -rf ~/.terraform/virtualbox
rm -rf .terraform
rm -r .terraform.lock.hcl
rm -r terraform.tfstate
echo "--------------------------------------------------"

echo "Full reset workflow completed successfully."