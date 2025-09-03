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