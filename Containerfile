# --- Stage 1: Get Terraform binary ---
FROM docker.io/hashicorp/terraform:1.13.0 AS terraform

# --- Stage 2: Get Packer binary ---
FROM docker.io/hashicorp/packer:1.14.1 AS packer

# --- Stage 3: Get Vault binary ---
FROM docker.io/hashicorp/vault:1.20.2 AS vault

# --- Final Stage: Build our unified QEMU/KVM controller image ---
FROM ubuntu:24.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies for IaC tools and QEMU/KVM client interaction
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    openssh-client \
    git \
    curl \
    jq \
    ca-certificates \
    # Python for Ansible
    python3 \
    python3-pip \
    # KVM/Libvirt client tools for Packer/Terraform/virsh
    libvirt-clients \
    qemu-system-x86 \
    qemu-utils \
    # Tool for creating ISO 9660 images, required by Packer for cd_content
    xorriso \
    genisoimage \
    # Ansible
    software-properties-common \
    && add-apt-repository --yes --update ppa:ansible/ansible \
    && apt-get install -y ansible \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Configure QEMU for non-root user bridge access, mirroring the native setup fixes.
RUN mkdir -p /etc/qemu && \
    echo 'allow virbr0' > /etc/qemu/bridge.conf && \
    chmod u+r /etc/qemu/bridge.conf

# Copy binaries from HashiCorp stages
COPY --from=terraform /bin/terraform /usr/local/bin/terraform
COPY --from=packer /bin/packer /usr/local/bin/packer
COPY --from=vault /bin/vault /usr/local/bin/vault

# # Create user to match host HOST_UID:HOST_GID and username
ARG HOST_UID
ARG HOST_GID
ARG USERNAME
ARG LIBVIRT_GID

RUN \
    # Ensure the libvirt group exists and the GID is correct
    if ! getent group ${LIBVIRT_GID} > /dev/null 2>&1; then \
        groupadd -g ${LIBVIRT_GID} libvirt; \
    else \
        EXISTING_LIBVIRT_GROUP_NAME=$(getent group ${LIBVIRT_GID} | cut -d: -f1); \
        if [ "${EXISTING_LIBVIRT_GROUP_NAME}" != "libvirt" ]; then groupmod -n libvirt ${EXISTING_LIBVIRT_GROUP_NAME}; fi; \
    fi && \
    \
    # Handle user's primary group
    if ! getent group ${HOST_GID} > /dev/null 2>&1; then \
        groupadd -g ${HOST_GID} ${USERNAME}; \
    else \
        EXISTING_GROUP_NAME=$(getent group ${HOST_GID} | cut -d: -f1); \
        if [ "${EXISTING_GROUP_NAME}" != "${USERNAME}" ]; then groupmod -n ${USERNAME} ${EXISTING_GROUP_NAME}; fi; \
    fi && \
    \
    # Handle user
    if ! getent passwd ${HOST_UID} > /dev/null 2>&1; then \
        useradd -u ${HOST_UID} -g ${HOST_GID} -m -s /bin/bash ${USERNAME}; \
    else \
        EXISTING_USER_NAME=$(getent passwd ${HOST_UID} | cut -d: -f1); \
        usermod -l ${USERNAME} -u ${HOST_UID} -g ${HOST_GID} -d /home/${USERNAME} -m ${EXISTING_USER_NAME}; \
    fi && \
    \
    # Unconditionally add the final user to the libvirt group
    usermod -a -G libvirt ${USERNAME}

USER ${USERNAME}

# --- Final container setup ---
WORKDIR /app

CMD ["/bin/bash"]
