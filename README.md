1. **Do this if you haven’t installed VirtualBox**

```bash
sudo apt install virtualbox virtualbox-dkms -y
sudo apt install virtualbox-ext-pack -y
```

2. **Install HashiCorp Toolkits - Terraform and Packer**

<aside>
REF：https://developer.hashicorp.com/terraform/install
REF：https://developer.hashicorp.com/packer/install
</aside>

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform packer -y
```

3. **Install Ansible**



```bash
sudo apt install software-properties-common -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible -y
```

> *On older Ubuntu distributions, “`software-properties-common`” is called “`python-software-properties`”. You may want to use `apt-get` rather than `apt` in older versions. Also, be aware that only newer distributions (that is, 18.04, 18.10, and later) have a `-u` or `--update` flag. Adjust your script as needed.*
> REF：https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-ubuntu
>

4. **Verification**

```bash
# Verify VirtualBox
vboxmanage --version

# Verify Packer
packer --version

# Verify Terraform
terraform --version

# Verify Ansible
ansible --version
```