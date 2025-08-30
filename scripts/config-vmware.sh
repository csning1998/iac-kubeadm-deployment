#!/bin/bash

# -----------------------------------------------------------------------------
# Project Configuration File
# -----------------------------------------------------------------------------
#
# This file contains all variables exclusively used by the VMware Workstation
# It is loaded conditionally by entry.sh only when the host environment
# is Ubuntu/Debian and the selected Strategy is VMware.
#
# -----------------------------------------------------------------------------

###
# VM Network Configuration (Linux Distribution-Aware)
###

# Packer template name. This is used for naming the output directory and for cleanup.
PACKER_VM_NAME="ubuntu-server-k8s-based"

# The subdirectory name within `packer/output/` where the built VM files will be stored.
PACKER_OUTPUT_SUBDIR="ubuntu-server-vmware"

# Detect the Linux distribution and set network defaults accordingly.
# This approach is more robust for supporting multiple native Linux environments.
if [ -f /etc/os-release ]; then
  # Source the os-release file to get variables like $ID
  . /etc/os-release

  case $ID in
    ubuntu|debian)
      ### Debian / Ubuntu Family Defaults ###
      echo "INFO: Debian/Ubuntu environment detected. Using Debian family VMware defaults for networking."
      VMNET8_SUBNENT="172.16.86.0"
      VMNET8_NETMASK="255.255.255.0"
      VMNET8_GATEWAY="172.16.86.2"

      VMNET1_SUBNET="172.16.134.0"
      VMNET1_NETMASK="255.255.255.0"
      ;;
  esac
fi

# Set sane defaults if the variables were not set (e.g., /etc/os-release not found)
VMNET8_SUBNET=${VMNET8_SUBNET:-"172.16.86.0"}
VMNET8_NETMASK=${VMNET8_NETMASK:-"255.255.255.0"}
VMNET8_GATEWAY=${VMNET8_GATEWAY:-"172.16.86.2"}
VMNET1_SUBNET=${VMNET1_SUBNET:-"172.16.134.0"}
VMNET1_NETMASK=${VMNET1_NETMASK:-"255.255.255.0"}

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