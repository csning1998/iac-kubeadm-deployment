#!/bin/bash

set -e -u

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
readonly PACKER_DIR="${SCRIPT_DIR}/packer"
readonly PACKER_VM_NAME="ubuntu-server-24-template"
readonly PACKER_OUTPUT_DIR="${PACKER_DIR}/output/ubuntu-server"

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
echo ">>> STEP 2: Cleaning up old Packer artifacts from VirtualBox..."

if VBoxManage showvminfo "$PACKER_VM_NAME" >/dev/null 2>&1; then
  echo "Found leftover Packer VM '$PACKER_VM_NAME'. Unregistering and deleting..."
  VBoxManage unregistervm "$PACKER_VM_NAME" --delete
else
  echo "No leftover Packer VM found. Skipping VirtualBox cleanup."
fi
echo "--------------------------------------------------"

# --- STEP 3: Cleaning output directory and starting new Packer build ---
echo ">>> STEP 3: Cleaning output directory and starting new Packer build..."
cd "${PACKER_DIR}"
find ~/.cache/packer -mindepth 1 ! -name '*.iso' -exec rm -rf {} +
rm -rf output/ubuntu-server

packer build .

echo "Packer build complete. New base image is ready."
echo "--------------------------------------------------"

# --- STEP 4: Unpack the OVA artifact ---
echo ">>> STEP 4: Unpacking OVA to bypass provider bug..."
cd "${PACKER_OUTPUT_DIR}"
tar -xvf ./*.ova # An .ova file is a tar archive. We unpack it in place.
echo "Unpacking complete. .ovf and .vmdk are now available."
cd "${SCRIPT_DIR}" # Return to the project root
echo "--------------------------------------------------"

# --- Step 5: Deploy New VMs with Terraform ---
echo ">>> STEP 5: Initializing Terraform and applying configuration..."

cd "${TERRAFORM_DIR}"
rm -rf ~/.terraform/virtualbox
rm -rf .terraform
rm -r .terraform.lock.hcl
rm -r terraform.tf*

terraform init
terraform apply -auto-approve

echo "Terraform apply complete. New VMs are running."
echo "--------------------------------------------------"

echo "Full rebuild workflow completed successfully."