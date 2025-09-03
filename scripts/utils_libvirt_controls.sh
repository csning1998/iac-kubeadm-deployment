#!/bin/bash

# This script contains functions for controlling KVM/libvirt services and VMs.

# Function: Ensure libvirt service is running before executing a command.
ensure_libvirt_services_running() {
  echo "#### Checking status of libvirt service..."

  # Use 'is-active' for a clean check without parsing text.
  if ! sudo systemctl is-active --quiet libvirtd; then
    echo "--> libvirt service is not running. Attempting to start it..."
    
    # Use 'sudo' as this is a system-level service.
    if sudo systemctl start libvirtd; then
      echo "--> libvirt service started successfully."
      # Give the service a moment to initialize networks.
      sleep 2
    else
      echo "--> ERROR: Failed to start libvirt service. Please check 'systemctl status libvirtd'."
      # Exit the script if the core dependency cannot be started.
      exit 1
    fi
  else
    echo "--> libvirt service is already running."
  fi
}

# Function: Forcefully clean up all libvirt resources associated with this project.
purge_libvirt_resources() {
  echo ">>> STEP: Purging stale libvirt resources..."

  # Destroy and undefine all VMs (domains)
  for vm in $(sudo virsh list --all --name | grep 'k8s-'); do
    echo "#### Destroying and undefining VM: $vm"
    sudo virsh destroy "$vm" >/dev/null 2>&1 || true
    sudo virsh undefine "$vm" --remove-all-storage >/dev/null 2>&1 || true
  done

  # Delete all associated storage volumes
  for vol in $(sudo virsh vol-list iac-kubeadm | grep 'k8s-' | awk '{print $1}'); do
    echo "#### Deleting volume: $vol"
    sudo virsh vol-delete --pool iac-kubeadm "$vol" >/dev/null 2>&1 || true
  done

  # Destroy and undefine the networks
  for net in iac-kubeadm-nat-net iac-kubeadm-hostonly-net; do
    if sudo virsh net-info "$net" >/dev/null 2>&1; then
      echo "#### Destroying and undefining network: $net"
      sudo virsh net-destroy "$net" >/dev/null 2>&1 || true
      sudo virsh net-undefine "$net" >/dev/null 2>&1 || true
    fi
  done

  echo "#### Libvirt resource purge complete."
  echo "--------------------------------------------------"
}