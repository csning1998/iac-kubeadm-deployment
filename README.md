# PoC: Deploy HA Kubernetes Cluster using QEMU + KVM with Packer, Terraform, and Ansible

## Section 0. Introduction

This project serves as a personal learning initiative for IaC, utilizing QEMU-KVM to set up an HA Kubernetes Cluster in an on-premise environment. I created it mainly because I wanted to learn IaC and Kubernetes, but had exhausted my GCP free credits. Since this is currently being developed independently, the project has only been tested on RHEL 10 and Ubuntu 24 operating systems. Everyone is welcome to fork it for experimentation.

The machine specifications used for development are as follows, for reference:

-  Chipset: Intel® HM770
-  CPU: Intel® Core™ i7 processor 14700HX
-  RAM: Micron Crucial Pro 64GB Kit (32GBx2) DDR5-5600 UDIMM
-  SSD: WD PC SN560 SDDPNQE-1T00-1032

You can clone the project using the following command:

```shell
git clone https://github.com/csning1998/iac-kubeadm-deployment.git
```

### Disclaimer

-  This project currently only works on Linux devices with CPU virtualization support, and has not yet been tested on other distros such as Fedora 41, Arch, CentOS, and WSL2.
-  Currently, these features have only been tested on my personal computer through several system reinstallations, so there may inevitably be some functionality issues. I've tried my best to prevent and address these.

### Note

This project requires CPU with virtualization support. For users whose CPUs don't support virtualization, you can refer to the `legacy-workstation-on-ubuntu` branch. This has been tested on Ubuntu 24 to achieve the same basic functionality. Use the following in shell to check if your device support virtualization:

```bash
lscpu | grep Virtualization
```

The output may show:

-  Virtualization: VT-x (Intel)
-  Virtualization: AMD-V (AMD)
-  If there is no output, virtualization might not be supported.

### The Entrypoint: `entry.sh`

The content in Section 1 and Section 2 serves as prerequisite setup before formal execution. Project lifecycle management and configuration are handled through the `entry.sh` script in the root directory. After executing `./entry.sh`, you will see the following content:

```text
➜  iac-kubeadm-deployment git:(main) ✗ ./entry.sh
... (Some preflight check)
======= IaC-Driven Virtualization Management =======

Environment: NATIVE

1) Switch Environment Strategy                   8) Rebuild Packer
2) Verify IaC Environment for Native             9) Rebuild Terraform: All Stages
3) Setup KVM / QEMU for Native                  10) Rebuild Terraform Stage I: Configure Nodes
4) Setup Core IaC Tools for Native              11) Rebuild Terraform Stage II: Ansible
5) Generate SSH Key                             12) [DEV] Rebuild Stage II via Ansible
6) Reset All                                    13) Verify SSH
7) Rebuild All                                  14) Quit
>>> Please select an action:
```

### Prerequisites

Before you begin, ensure you have the following:

-  A Linux host (RHEL 10 or Ubuntu 24 recommended).
-  A CPU with virtualization support enabled (VT-x or AMD-V).
-  `sudo` access.
-  `podman` and `podman compose` installed (for containerized mode).
-  `whois` package installed (for the `mkpasswd` command).

**A description of how to use this script follows below.**

## Section 1. Environmental Setup

### Required. KVM / QEMU

The user's CPU must support virtualization technology to enable QEMU-KVM functionality. You can choose whether to install it through option 3 via script (but this has only been tested on Ubuntu 24 and RHEL 10), or refer to relevant resources to set up the KVM and QEMU environment on your own.

### Option 1. Install IaC tools on Native

1. **Install HashiCorp Toolkit - Terraform and Packer**

   Next, you can install Terraform, Packer, and Ansible by running `entry.sh` in the project root directory and selecting the fourth option _"Setup Core IaC Tools for Native"_. Or alternatively, follow the offical installation guide:

   > _Reference: [Terraform Installation](https://developer.hashicorp.com/terraform/install)_  
   > _Reference: [Packer Installation](https://developer.hashicorp.com/packer/install)_ > _Reference: [Ansible Installation](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)_

   Expected output should reflect the latest versions. For instance (in zsh):

   ```text
   ...
   >>> Please select an action: 2
   >>> STEP: Verifying full native IaC environment...
   >>> Verifying Libvirt/KVM environment...
   #### QEMU/KVM: Installed
   #### Libvirt Client (virsh): Installed
   >>> Verifying Core IaC Tools (HashiCorp/Ansible)...
   #### HashiCorp Packer: Installed
   #### HashiCorp Terraform: Installed
   #### HashiCorp Vault: Installed
   #### Red Hat Ansible: Installed
   ```

### Option 2. Run IaC tools inside Container: Podman

1. Please ensure Podman is installed correctly. You can refer to the following URL and choose the installation method corresponding to your platform

2. After completing the Podman installation, please switch to the project root directory:

   1. If using for the first time, execute the following command

      ```shell
      sudo podman compose -f compose.yml up --build
      ```

   2. After creating the Container, you only need to run the container to perform operations:

      ```shell
      sudo podman compose -f compose.yml up -d
      ```

   3. Currently, the default setting is `DEBIAN_FRONTEND=noninteractive`. If you need to make any modifications and check inside the container, you can execute

      ```shell
      sudo podman exec -it iac-controller bash
      ```

      Where `iac-controller` is the Container name for the project.

### Miscellaneous

-  **Suggested Plugins for VSCode:** Enhance productivity with syntax support:

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

## Section 2. Configuration

### Step A. Initial Project Setup

To ensure the project runs smoothly, please follow the procedures below to complete the initialization setup.

0. **Environment variable file:** The script `entry.sh` will automatically create a `.env` environment variable that is used by for script files, which can be ignored. This will later be integrated into the HashiCorp Vault workflow (with the following setup).

1. **Switch Environment:** You can switch between "Container" or "Native" environment by using `./entry.sh` and entering `1`. Currently this project primarily uses Podman, and I _personally_ recommend decoupling the Podman and Docker runtime environments to prevent execution issues caused by SELinux-related permissions. For example, SELinux policies do not allow a `container_t` process that is common in Docker to connect to a `virt_var_run_t` Socket, which may cause Terraform Provider or `virsh` to receive "Permission Denied" errors when running in containers, even though everything appears normal from a filesystem permissions perspective.

2. **Generate SSH Key:** During the execution of Terraform and Ansible, SSH keys will be used for node access authentication and configuration management. You can generate these by running `./entry.sh` and entering `5` to access the _"Generate SSH Key"_ option. You can enter your desired key name or simply use the default value `id_ed25519_iac-kubeadm-deployment`. The generated public and private key pair will be stored in the `~/.ssh` directory

3. **Create Secret Variable Files (Would be further integrated into HashiCorp Vault)**

   During the Packer and Terraform execution process, user-defined variables need to be set up, which requires manually creating the following variable files. For security considerations, these files have already been preconfigured in `.gitignore` and will not be included in version control.

   -  **For Packer:** You can create the `packer/secret.auto.pkrvars.hcl` file using the following command:

      ```bash
      VM_USERNAME="YOUR_VM_USERNAME"
      VM_PASSWORD="YOUR_VM_PASSWORD"
      HASHED_PASSWORD=$(echo -n "$VM_PASSWORD" | mkpasswd -m sha-512 -P 0)

      cat << EOF > packer/secret.auto.pkrvars.hcl
      ssh_username = "$VM_USERNAME"
      ssh_password = "$VM_PASSWORD"
      ssh_password_hash = "$HASHED_PASSWORD"
      ssh_public_key_path = "~/.ssh/id_ed25519_iac-kubeadm-deployment.pub"
      EOF
      ```

      In which `ssh_username` and `ssh_password` are the account and password used to log into the virtual machine; while `ssh_password_hash` is the hashed password required for virtual machine automatic installation (Cloud-init). This password needs to be generated using the password string from `ssh_password`. For instance, if the password is `HelloWorld@k8s`, then the corresponding password hash should be generated using the following command:

      ```bash
      mkpasswd -m sha-512 HelloWorld@k8s
      ```

      If it shows `mkpasswd` command not found, possibly due to lack of `whois` package.

      And `ssh_public_key_path`: needs to be changed to the **public key** name generated earlier, the public key will be in `*.pub` format

   -  **For Terraform:** You can create the `terraform/terraform.tfvars` file using the following command with `VM_USERNAME` and `VM_PASSWORD` above:

      ```bash
      cat << EOF > terraform/terraform.tfvars

      vm_username = "$VM_USERNAME"
      vm_password = "$VM_PASSWORD"
      ssh_private_key_path = "~/.ssh/id_ed25519_iac-kubeadm-deployment"

      node_configs = {
         masters = [
            { ip = "172.16.134.200", vcpu = 4, ram = 4096 },
            # Uncomment the following object for HA Cluster
            # { ip = "172.16.134.201", vcpu = 4, ram = 4096 },
            # { ip = "172.16.134.202", vcpu = 4, ram = 4096 }
         ]
         workers = [
            { ip = "172.16.134.210", vcpu = 4, ram = 4096 },
            { ip = "172.16.134.211", vcpu = 4, ram = 4096 },
            { ip = "172.16.134.212", vcpu = 4, ram = 4096 }
            # You may add more nodes as you wish if as long as the resource is sufficient.
         ]
      }

      # Kubernetes network configuration
      k8s_ha_virtual_ip = "172.16.134.250"
      k8s_pod_subnet    = "10.244.0.0/16"
      nat_gateway       = "172.16.86.2"
      nat_subnet_prefix = "172.16.86"
      EOF
      ```

   For users setting up an (HA) Cluster, the number of elements in `node_configs.masters` and `node_configs.workers` determines the number of nodes generated. Ensure the quantity of nodes in `node_configs.masters` is an odd number to prevent the etcd Split-Brain risk in Kubernetes. Meanwhile, `node_configs.workers` can be configured based on the number of IPs. The IPs provided by the user must correspond to the host-only network segment.

   **Note:** Please make sure to replace `YOUR_VM_USERNAME` and `YOUR_VM_PASSWORD` with the actual credentials you wish to use. If you specified a non-default key name in the previous step, you must also update the `ssh_public_key_path` and `ssh_private_key_path` fields accordingly

4. The project currently uses Ubuntu 24.04.3 for VM deployment. If you wish to use other distro as virtual machine, it is recommended that you first verify the Ubuntu Server version and checksum.

   -  The latest version is available at <https://cdimage.ubuntu.com/ubuntu/releases/24.04/release/> ,
   -  The test version of this project is also available at <https://old-releases.ubuntu.com/releases/noble/> .
   -  After selecting your version, please verify the checksum.
      -  For latest Noble version: <https://releases.ubuntu.com/noble/SHA256SUMS>
      -  For "Noble-old-release" version: <https://old-releases.ubuntu.com/releases/noble/SHA256SUMS>

   Deploying other Linux distro would be supported if I have time. I'm still a full-time university student.

5. After completing all the above setup steps, you can use `entry.sh`, enter `7` to access _"Rebuild All"_ to perform automated deployment of the Kubernetes cluster. Based on testing, the current complete deployment of a HA Kubernetes Cluster takes approximately 7 minutes from Packer to finished.

> The setup process is based on the commands provided by Bibin Wilson (2025), which I implemented using an Ansible Playbook. Thanks to the author, Bibin Wilson, for the contribution on his article
>
> Work Cited: Bibin Wilson, B. (2025). _How To Setup Kubernetes Cluster Using Kubeadm._ devopscube. <https://devopscube.com/setup-kubernetes-cluster-kubeadm/#vagrantfile-kubeadm-scripts-manifests>

## Section 3. System Architecture

This project employs three tools - Packer, Terraform, and Ansible - using an Infrastructure as Code (IaC) approach to achieve a fully automated workflow from virtual machine image creation to Kubernetes cluster deployment. The overall architecture follows the principle of Immutable Infrastructure, ensuring that each deployment environment is consistent and predictable.

### Deployment Workflow

The entire automated deployment process is triggered by the sixth option _"Rebuild All"_ in the `./entry.sh` script, with detailed steps shown in the diagram below:

```mermaid
sequenceDiagram
   actor User
   participant Entrypoint as entry.sh
   participant Packer
   participant Terraform
   participant Ansible
   participant Libvirt as Libvirt/QEMU

   User->>+Entrypoint: Execute 'Rebuild All'

   Entrypoint->>+Packer: 1. Execute 'build_packer'
   Packer->>+Libvirt: 1a. Build VM from ISO
   note right of Packer: Provisioner 'ansible' is triggered
   Packer->>+Ansible: 1b. Execute Playbook<br>(00-provision-base-image.yaml)
   Ansible-->>-Packer: (Bake k8s components into image)
   Libvirt-->>-Packer: 1c. Output Golden Image (.qcow2)
   Packer-->>-Entrypoint: Image creation complete

   Entrypoint->>+Terraform: 2. Execute 'apply_terraform_all_stages'
   note right of Terraform: Reads .tf definitions
   Terraform->>+Libvirt: 2a. Create Network, Pool, Volumes (from .qcow2), Cloud-init ISOs
   Terraform->>+Libvirt: 2b. Create and Start VMs (Domains)
   note right of Terraform: Provisioner 'local-exec' is triggered
   Terraform->>+Ansible: 2c. Execute Playbook<br>(10-provision-cluster.yaml)
   Ansible->>Libvirt: (via SSH) 2d. Configure HA (Keepalived/HAProxy)
   Ansible->>Libvirt: (via SSH) 2e. Init/Join Kubernetes Cluster
   Ansible-->>-Terraform: Playbook execution complete
   Terraform-->>-Entrypoint: 'apply' complete
   Entrypoint-->>-User: Display 'Rebuild All workflow completed'
```

### Toolchain Roles and Responsibilities

1. **Packer + Ansible: Provisioning base Kubernetes Golden Image**

   Packer plays the role of an "image factory" in this project, with its core task being to automate the creation of a standardized virtual machine template (Golden Image) pre-configured with all Kubernetes dependencies. The project uses `packer/source-qemu.pkr.hcl` as its definition file, with a workflow that includes: automatically downloading the `Ubuntu Server 24.04 ISO` file and completing unattended installation using cloud-init; starting SSH connection and invoking the Ansible Provisioner after installation; executing `ansible/playbooks/00-provision-base-image.yaml` to install necessary components such as `kubelet`, `kubeadm`, `kubectl`, and `CRI-O` (also configure it to use `cgroup` driver); finally shutting down the virtual machine and producing a `*.qcow2` format template for Terraform to use. The goal of this phase is to "bake" all infrequently changing software and configurations into the image to reduce the time required for subsequent deployments.

2. **Terraform: The Infrastructure Orchestrator**

   Terraform is responsible for managing the infrastructure lifecycle and serves as the core orchestration component of the entire architecture. Terraform reads the image template produced by Packer and deploys the actual virtual machine cluster in Libvirt/QEMU. The definition files are the `.tf` files in the `terraform/` directory, with the **workflow as follows:**

   -  **Node Deployment (Stage I)**:

      -  Based on `node_configs` defined in `terraform/terraform.tfvars`, Terraform calculates the number of nodes that need to be created.
      -  Next, Terraform's libvirt provider will quickly clone virtual machines based on the `.qcow2` file. Under the hardware resources listed in Section 0, cloning 6 virtual machines can be completed in approximately 15 seconds.

   -  **Cluster Configuration (Stage II)**:
      -  Once all nodes are ready, Terraform dynamically generates `ansible/inventory.yaml` list file.
      -  Then, Terraform invokes Ansible to execute the `ansible/playbooks/10-provision-cluster.yaml` Playbook to complete the initialization of the Kubernetes cluster.

3. **Ansible: The Configuration Manager**

   This is the twice call for Ansible, serving as the configuration manager at different stages. The project's Playbooks are stored in the `ansible/playbooks/ directory`. In terms of role assignment, Ansible is primarily responsible for cluster initialization (invoked by Terraform), executing the following tasks through the `10-provision-cluster.yaml` Playbook:

   1. Setup HA Load Balancer on all master nodes if it's not a cluster with single master node.
   2. Initialize the primary master node
   3. Generate and fetch join commands from primary master
   4. Executing `kubeadm join` on
      1. Other master node if it's HA Cluster
      2. Worker nodes to join them to the cluster.

4. **HashiCorp Vault**

   Currently working in progress...
