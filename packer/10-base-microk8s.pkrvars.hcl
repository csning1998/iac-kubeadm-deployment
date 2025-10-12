
# This file defines the variables for building the 'registry-base' image.

build_spec = {
  suffix   = "10-base-microk8s"
  vnc_port = 5998
}

# The following common variables are inherited from the main 'values.pkrvars.hcl'
# but could be overridden here if needed for a specific build.
#
# vm_name      = "ubuntu-server-24"
# iso_url      = "https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
# iso_checksum = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"
# cpus         = 2
# memory       = 2048
# disk_size    = 40960