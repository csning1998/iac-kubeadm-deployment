#!/bin/bash

set -e -u

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly PACKER_VM_NAME="ubuntu-server-24-template"
# This variable is currently unused but kept for consistency
readonly PACKER_OUTPUT_DIR="${PACKER_DIR}/output/ubuntu-server"

# --- STEP 0: Purging all Inaccessible VirtualBox Hard Disks ---
# This step is good practice for VirtualBox maintenance and does not conflict with Terraform.
echo ">>> STEP 0: Purging all inaccessible VirtualBox hard disks..."
VBoxManage list hdds | awk -v RS= '/inaccessible/ {print $2}' | while read -r uuid; do
    echo "Removing inaccessible HDD with UUID: $uuid"
    VBoxManage closemedium disk "$uuid" --delete || echo "Warning: Failed to remove medium $uuid. It might already be gone."
done
echo "VirtualBox media registry cleaned."
echo "--------------------------------------------------"

# --- Step 1: Destroy Existing Terraform Resources ---
# This is the primary change. We let Terraform read its state file and handle the destruction of the VMs it manages.
echo ">>> STEP 1: Destroying existing Terraform-managed VMs..."
cd "${TERRAFORM_DIR}"
terraform init -upgrade
# Let Terraform handle the destruction based on its state file.
# This will correctly power off, unregister, and delete the VMs.
terraform destroy -parallelism=1 -auto-approve -lock=false
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
echo "--------------------------------------------------"

# --- Step 3: Deploy New VMs with Terraform ---
echo ">>> STEP 3: Initializing Terraform and applying configuration..."
cd "${TERRAFORM_DIR}"
rm -rf ~/.terraform/virtualbox
rm -rf .terraform
rm -f .terraform.lock.hcl
rm -f terraform.tfstate

terraform init
terraform apply -parallelism=1 -auto-approve

echo "Terraform apply complete. New VMs are running."
echo "--------------------------------------------------"

echo "Terraform rebuild workflow completed successfully."