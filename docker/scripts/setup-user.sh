#!/bin/bash
set -e

# Create developer user with sudo privileges
useradd -m -s /bin/bash -G sudo developer

# Set initial password (will be disabled later for SSH key-only access)
echo "developer:developer" | chpasswd

# Configure sudo access without password
echo "developer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer

# Create workspace directory (will be mounted as volume)
mkdir -p /workspace
chown developer:developer /workspace
chmod 755 /workspace

# Create scripts directory in workspace
mkdir -p /workspace/scripts
chown developer:developer /workspace/scripts