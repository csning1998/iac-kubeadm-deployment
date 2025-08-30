#!/bin/bash

# -----------------------------------------------------------------------------
# Project Core Configuration File
# -----------------------------------------------------------------------------
#
# This file contains all the user-configurable variables for the project.
# These settings determine the core execution strategies and can be
# modified via the interactive menu in entry.sh
#
# -----------------------------------------------------------------------------

###
# Defines the virtualization technology to be used.
## "kvm": Use QEMU/KVM for virtualization. (Requires CPU hardware virtualization support)
## "vmware": Use VMware Workstation Pro. (Fallback for systems without virt support on Ubuntu)
VIRTUALIZATION_PROVIDER="kvm"

###
# Defines the environment for running IaC tools.
## "container": Use a containerized environment (Podman or Docker). (Default)
## "native": Use tools installed directly on the host.
ENVIRONMENT_STRATEGY="container"

###
# Defines the container engine to use when ENVIRONMENT_STRATEGY is "container".
## "podman": Recommended for RHEL/Fedora hosts.
## "docker": Recommended for Ubuntu/Debian hosts.
CONTAINER_ENGINE="podman"


###
# Virtual Machine and User Configuration
## Default username for the virtual machines.
## If left empty (""), the script will default to the current logged-in user (`whoami`).
VM_USERNAME=""

# The generate_ssh_key function allows creating a key with a custom name.
SSH_PRIVATE_KEY="$HOME/.ssh/id_ed25519_iac_automation"