#!/bin/bash
set -e

echo "🚀 Starting Claude Development Environment..."

# Configure SSH keys from environment variable
if [ ! -z "$AUTHORIZED_KEYS" ]; then
    echo "🔑 Configuring SSH keys..."
    echo "$AUTHORIZED_KEYS" > /home/developer/.ssh/authorized_keys
    chown developer:developer /home/developer/.ssh/authorized_keys
    chmod 600 /home/developer/.ssh/authorized_keys
    echo "✅ SSH keys configured"
else
    echo "⚠️  No SSH keys found in AUTHORIZED_KEYS environment variable"
fi

# Ensure workspace exists and has correct permissions
echo "📁 Setting up workspace..."
if [ ! -d "/workspace" ]; then
    mkdir -p /workspace
fi
chown -R developer:developer /workspace
chmod 755 /workspace

# Create essential directories in workspace if they don't exist
sudo -u developer mkdir -p /workspace/projects
sudo -u developer mkdir -p /workspace/scripts
sudo -u developer mkdir -p /workspace/backups
sudo -u developer mkdir -p /workspace/.cache

# Copy install-claude-tools.sh if it doesn't exist
if [ ! -f "/workspace/scripts/install-claude-tools.sh" ]; then
    cp /docker/scripts/install-claude-tools.sh /workspace/scripts/
    chown developer:developer /workspace/scripts/install-claude-tools.sh
    chmod +x /workspace/scripts/install-claude-tools.sh
fi

# Set up environment variables for developer user
if [ ! -z "$ANTHROPIC_API_KEY" ]; then
    echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" >> /home/developer/.bashrc
fi

# Start SSH daemon
echo "🔌 Starting SSH daemon..."
mkdir -p /var/run/sshd
/usr/sbin/sshd -D &

# Keep container running and handle signals
echo "🎯 Claude Development Environment is ready!"
echo "📡 SSH server listening on port 22"
echo "🏠 Workspace mounted at /workspace"

# Handle shutdown gracefully
trap 'echo "📴 Shutting down..."; kill $(jobs -p); exit 0' SIGTERM SIGINT

# Wait for SSH daemon
wait $!