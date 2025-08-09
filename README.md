
# Proof of Concepts on IaC Toolkits: Deploy VMs on Workstation 17.x using Packer + Terraform + Ansible

## Section 0. Environmental Setup

1. **Install VMware Workstation**

   VMware Workstation is required for virtualization. Execute the following commands to install it:

   ```shell
   sudo apt update
   sudo apt install wget gnupg2 -y
   wget https://www.vmware.com/go/getworkstation-linux -O vmware-workstation.bundle
   chmod +x vmware-workstation.bundle
   sudo ./vmware-workstation.bundle --eulas-agreed --required
   ```

   After installation, configure VMware Network Editor:
   - Open VMware Network Editor (`vmware-netcfg`).
   - Ensure `vmnet8` is set to NAT with subnet `172.16.86.0/24` and DHCP enabled.
   - Ensure `vmnet1` is set to Host-only with subnet `172.16.134.0/24` (no DHCP).

2. **Install HashiCorp Toolkits - Terraform and Packer**

   > _Reference: [Terraform Installation](https://developer.hashicorp.com/terraform/install)_  
   > _Reference: [Packer Installation](https://developer.hashicorp.com/packer/install)_

   Add the HashiCorp repository and install the latest versions:

   ```shell
   wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform packer -y
   ```

3. **Install Ansible**

   > _Reference: [Ansible Installation on Ubuntu](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-ubuntu)_

   ```shell
   sudo apt install software-properties-common -y
   sudo add-apt-repository --yes --update ppa:ansible/ansible
   sudo apt install ansible -y
   ```

4. **Verification**

   Verify each tool to confirm successful setup:

   ```shell
   # Verify VMware Workstation
   vmware --version

   # Verify Packer
   packer --version

   # Verify Terraform
   terraform --version

   # Verify Ansible
   ansible --version
   ```

   Expected output should reflect the latest versions (e.g., Terraform > v1.5, Packer > v1.9, Ansible > v2.15). For instance (zsh):

   ```text
   (base) ➜  ~ vmware --version
   VMware Workstation 17.5.0 build-22583795
   (base) ➜  ~ packer --version
   Packer v1.9.4
   (base) ➜  ~ terraform --version
   Terraform v1.9.4
   on linux_amd64
   (base) ➜  ~ ansible --version
   ansible [core 2.18.7]
     config file = /etc/ansible/ansible.cfg
     configured module search path = ['/home/someUserName/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
     ansible python module location = /usr/lib/python3/dist-packages/ansible
     ansible collection location = /home/someUserName/.ansible/collections:/usr/share/ansible/collections
     executable location = /usr/bin/ansible
     python version = 3.12.3 (main, Jun 18 2025, 17:59:45) [GCC 13.3.0]
     jinja version = 3.1.2
     libyaml = True
   ```

5. **Suggested Plugins for VSCode**

   Enhance productivity with syntax support:

   1. Ansible language support extension. [Marketplace Link of Ansible](https://marketplace.visualstudio.com/items?itemName=redhat.ansible)

      ```shell
      code --install-extension redhat.ansible
      ```

   2. HCL language support extension for Terraform. [Marketplace Link of HashiCorp HCL](https://marketplace.visualstudio.com/items?itemName=HashiCorp.HCL)

      ```shell
      code --install-extension HashiCorp.HCL
      ```

   3. Packer tool extension. [Marketplace Link of Packer Powertools](https://marketplace.visualstudio.com/items?itemName=szTheory.vscode-packer-powertools)

      ```shell
      code --install-extension szTheory.vscode-packer-powertools
      ```

## Section 1. Network Configuration

- **NAT Network (`vmnet8`)**: Configured with subnet `172.16.86.0/24` to provide external internet access via DHCP.
- **Host-only Network (`vmnet1`)**: Configured with subnet `172.16.134.0/24` for internal communication, using static IPs (e.g., `172.16.134.101` for `node-1`).

Ensure these settings are applied in VMware Network Editor before deployment.

## Section 2. Deployment Verification

1. After running `terraform apply  -parallelism=1 -auto-approve -lock=false`, verify the deployment:

   - Check `vms/node-X/nat_ip.txt` for NAT IPs (e.g., `172.16.86.x`).
   - SSH to each Host-only IP (e.g., `172.16.134.101`, `172.16.134.102`, `172.16.134.103`) and run:

      ```shell
      ip a show ens32
      hostname
      ```

   - Ensure `ens32` is `UP` with the correct IP and hostname matches (`node-1`, `node-2`, `node-3`).

2. If issues arise, check `ip route` and Netplan logs:

   ```shell
   sudo journalctl -u netplan
   ```
