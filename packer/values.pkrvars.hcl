# This file provides default values for common variables.

vm_name = "ubuntu-server-24"

/*
The latest version is available at https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/ , 
and a project test version is also available at https://old-releases.ubuntu.com/releases/noble/ .
After selecting your version, please verify the checksum.
- For latest Noble version: https://releases.ubuntu.com/noble/SHA256SUMS
- For "Noble-old-release" version: https://old-releases.ubuntu.com/releases/noble/SHA256SUMS
*/

iso_url      = "https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
iso_checksum = "sha256:c3514bf0056180d09376462a7a1b4f213c1d6e8ea67fae5c25099c6fd3d8274b"

cpus      = 2
memory    = 2048
disk_size = 40960

disk_adapter_type = "scsi"