#!/bin/bash
set -e

# Create developer user with sudo privileges
# -M flag: don't create home directory (will be created on persistent volume)
useradd -M -s /bin/bash -G sudo developer

# Set initial password (will be disabled later for SSH key-only access)
echo "developer:developer" | chpasswd

# Configure sudo access without password
echo "developer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer

# Create workspace mount point (will be mounted as volume)
# Note: The actual workspace directories and developer home will be created
# in entrypoint.sh after the volume is mounted
mkdir -p /workspace
chmod 755 /workspace