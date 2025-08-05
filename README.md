# Packer + Terraform + Ansible

## Section 0. Environmental Setup

1. **Install VirtualBox (if not already installed)**

   Given that VirtualBox is required for virtualization, execute the following commands to install it along with necessary extensions:

   ```shell
   sudo apt install virtualbox virtualbox-dkms -y
   sudo apt install virtualbox-ext-pack -y
   ```

2. **Install HashiCorp Toolkits - Terraform and Packer**

   > _Reference: [Terraform Installation](https://developer.hashicorp.com/terraform/install)_  
   > _Reference: [Packer Installation](https://developer.hashicorp.com/packer/install)_

   Add the HashiCorp repository such that it supports your Ubuntu version, and install the tools:

   ```shell
   wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform packer -y
   ```

3. **Install Ansible**

   > For compatibility with older Ubuntu distributions, note that "software-properties-common" may be called "python-software-properties", and use `apt-get` if needed. Newer versions (18.04+) support the `--update` flag; adjust accordingly.
   > _Reference: [Ansible Installation on Ubuntu](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-ubuntu)_

   ```shell
   sudo apt install software-properties-common -y
   sudo add-apt-repository --yes --update ppa:ansible/ansible
   sudo apt install ansible -y
   ```

4. **Verification**

   Therefore, after installation, verify each tool to confirm successful setup:

   ```shell
   # Verify VirtualBox
   vboxmanage --version

   # Verify Packer
   packer --version

   # Verify Terraform
   terraform --version

   # Verify Ansible
   ansible --version
   ```

   The result you see on terminal should be similar as follow:

   ```text
   (base) ➜  ~ vboxmanage --version
   7.0.26r168464
   (base) ➜  ~ packer --version
   Packer v1.13.1
   (base) ➜  ~ terraform --version
   Terraform v1.12.2
   on linux_amd64
   (base) ➜  ~ ansible --version
   ansible [core 2.18.7]
     config file = /etc/ansible/ansible.cfg
     configured module search path = ['/home/someUsername/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
     ansible python module location = /usr/lib/python3/dist-packages/ansible
     ansible collection location = /home/someUsername/.ansible/collections:/usr/share/ansible/collections
     executable location = /usr/bin/ansible
     python version = 3.12.3 (main, Jun 18 2025, 17:59:45) [GCC 13.3.0] (/usr/bin/python3)
     jinja version = 3.1.2
     libyaml = True
   ```

5. **Suggested Plugins for VSCode**

   Installing these plugins will contribute to your working experience with Packer, Ansible, and HCL, thereby enhancing productivity through better syntax support and validation.

   1. Ansible language support extension, providing auto-completion and syntax checking.
      [Marketplace Link of Ansible](https://marketplace.visualstudio.com/items?itemName=redhat.ansible)

      ```shell
      code --install-extension redhat.ansible
      ```

   2. HCL language support extension, used for syntax highlighting and validation in tools like Terraform.
      [Marketplace Link of HashiCorp HCL](https://marketplace.visualstudio.com/items?itemName=HashiCorp.HCL)

      ```shell
      code --install-extension HashiCorp.HCL
      ```

   3. Packer tool extension, for syntax support and validation in HashiCorp Packer.
      [Marketplace Link of Packer Powertools](https://marketplace.visualstudio.com/items?itemName=szTheory.vscode-packer-powertools)

      ```shell
      code --install-extension szTheory.vscode-packer-powertools
      ```

## Section 1. Packer

(To be Continued...)
