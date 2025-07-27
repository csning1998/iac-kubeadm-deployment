#!/bin/bash

# --- Script Configuration ---
set -e

# --- Define Directories ---
TERRAFORM_DIR="./terraform"
PACKER_DIR="./packer"

# --- Step 1: Destroy Existing Terraform Resources ---
echo ">>> STEP 1: Destroying existing Terraform-managed VMs..."
cd "${TERRAFORM_DIR}"
terraform destroy -auto-approve
echo "Terraform destroy complete."
echo "--------------------------------------------------"


# --- Step 2: Clean Packer Artifacts & Build New Image ---
echo ">>> STEP 2: Cleaning old artifacts and starting new Packer build..."
cd .$PACKER_DIR
rm -rf output/ubuntu-24 
packer build .
echo "Packer build complete. New base image is ready."
echo "--------------------------------------------------"


# --- Step 3: Deploy New VMs with Terraform ---
echo ">>> STEP 3: Initializing Terraform and applying configuration..."
cd .$terraform 
terraform init
terraform apply -auto-approve
echo "Terraform apply complete. New VMs are running."
echo "--------------------------------------------------"

echo "Full rebuild workflow completed successfully."