#!/bin/bash

# -----------------------------------------------------------------------------
# Project Configuration File
# -----------------------------------------------------------------------------
#
# This file contains all the user-configurable variables for the project.
# Modify these values to suit your specific setup.
#
# -----------------------------------------------------------------------------

###
# Virtual Machine and User Configuration
###

# Default username for the virtual machines.
# If left empty (""), the script will default to the current logged-in user (`whoami`).
VM_USERNAME=""

# Packer template name. This is used for naming the output directory and for cleanup.
PACKER_VM_NAME="ubuntu-server-k8s-based"

# The subdirectory name within `packer/output/` where the built VM files will be stored.
PACKER_OUTPUT_SUBDIR="ubuntu-server-vmware"

# The generate_ssh_key function allows creating a key with a custom name.
SSH_PRIVATE_KEY="$HOME/.ssh/id_ed25519_iac_automation"

###
# Network Configuration
###

# VMware Workstation Network Configuration for automatic setup.
# These values will be written to /etc/vmware/networking.
VMNET8_SUBNET="172.16.86.0"
VMNET8_NETMASK="255.255.255.0"
VMNET1_SUBNET="172.16.134.0"
VMNET1_NETMASK="255.255.255.0"


# ====== DO NOT MODIFY THE HEREDOC BELOW ======
# It uses the variables defined above to generate the final configuration content.
# The HEREDOC uses "EOF" (without quotes) to allow variable expansion.
VMWARE_NETWORKING_CONFIG=$(cat <<EOF
VERSION=1,0
answer VNET_1_DHCP no
answer VNET_1_DISPLAY_NAME
answer VNET_1_HOSTONLY_NETMASK ${VMNET1_NETMASK}
answer VNET_1_HOSTONLY_SUBNET ${VMNET1_SUBNET}
answer VNET_1_VIRTUAL_ADAPTER yes
answer VNET_8_DHCP yes
answer VNET_8_DHCP_CFG_HASH B7DE0620494D07D87DE131EBECBC26E55A0AFD74
answer VNET_8_DISPLAY_NAME
answer VNET_8_HOSTONLY_NETMASK ${VMNET8_NETMASK}
answer VNET_8_HOSTONLY_SUBNET ${VMNET8_SUBNET}
answer VNET_8_NAT yes
answer VNET_8_VIRTUAL_ADAPTER yes
EOF
)