# --- Stage 1: Get Terraform binary ---
FROM hashicorp/terraform:1.13.0 AS terraform

# --- Stage 2: Get Packer binary ---
FROM hashicorp/packer:1.14.1 AS packer

# --- Stage 3: Get Vault binary ---
FROM hashicorp/vault:1.20.2 AS vault

# --- Final Stage: Build our unified image ---
FROM ubuntu:24.04

# # Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies, Python, pip, VMware dependencies, and Ansible
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    openssh-client \
    git \
    curl \
    jq \
    ca-certificates \
    python3 \
    python3-pip \
    libx11-6 \
    libxtst6 \
    libxkbcommon-x11-0 \
    libxml2 \
    libxml2-dev \
    libglib2.0-0 \
    libgcc-s1 \
    libgdk-pixbuf2.0-0 \
    libgtk-3-0 \
    libfuse2 \
    libaio1t64 \
    libssl3 \
    software-properties-common \
    && add-apt-repository --yes --update ppa:ansible/ansible \
    && apt-get install -y ansible \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy binaries from HashiCorp stages
COPY --from=terraform /bin/terraform /usr/local/bin/terraform
COPY --from=packer /bin/packer /usr/local/bin/packer
COPY --from=vault /bin/vault /usr/local/bin/vault

# Create user to match host HOST_UID:HOST_GID and username
ARG HOST_UID
ARG HOST_GID
ARG USERNAME

# user creation handler
# 1. find and remove any existing user/group with the target HOST_UID/HOST_GID.
# 2. create the new user with the specified name.

RUN export DEBIAN_FRONTEND=noninteractive && \
    EXISTING_USER=$(getent passwd ${HOST_UID} 2>/dev/null | cut -d: -f1) && \
    if [ -n "$EXISTING_USER" ]; then \
        deluser --remove-home "$EXISTING_USER" || true; \
    fi && \
    EXISTING_GROUP=$(getent group ${HOST_GID} 2>/dev/null | cut -d: -f1) && \
    if [ -n "$EXISTING_GROUP" ]; then \
        delgroup "$EXISTING_GROUP" || true; \
    fi && \
    groupadd -g ${HOST_GID} ${USERNAME} && \
    useradd -u ${HOST_UID} -g ${HOST_GID} -m -s /bin/bash ${USERNAME} && \
    mkdir -p /home/${USERNAME}/.cache/packer && \
    chown -R ${HOST_UID}:${HOST_GID} /home/${USERNAME}

USER ${USERNAME}

# --- Final container setup ---
WORKDIR /app

CMD ["/bin/bash"]