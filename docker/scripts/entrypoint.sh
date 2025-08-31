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

# Copy lib directory if it doesn't exist
if [ ! -d "/workspace/scripts/lib" ]; then
    cp -r /docker/lib /workspace/scripts/
    chown -R developer:developer /workspace/scripts/lib
    chmod +x /workspace/scripts/lib/*.sh
fi

# Copy vm-configure.sh if it doesn't exist
if [ ! -f "/workspace/scripts/vm-configure.sh" ]; then
    cp /docker/scripts/vm-configure.sh /workspace/scripts/
    chown developer:developer /workspace/scripts/vm-configure.sh
    chmod +x /workspace/scripts/vm-configure.sh
fi

# Set up environment variables for developer user
if [ ! -z "$ANTHROPIC_API_KEY" ]; then
    echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" >> /home/developer/.bashrc
fi

# Configure GitHub token if provided
if [ ! -z "$GITHUB_TOKEN" ]; then
    echo "🔐 Configuring GitHub authentication..."
    echo "export GITHUB_TOKEN='$GITHUB_TOKEN'" >> /home/developer/.bashrc

    # Create GitHub CLI config for gh commands
    sudo -u developer mkdir -p /home/developer/.config/gh
    echo "github.com:" > /home/developer/.config/gh/hosts.yml
    echo "    oauth_token: $GITHUB_TOKEN" >> /home/developer/.config/gh/hosts.yml
    echo "    user: $GITHUB_USER" >> /home/developer/.config/gh/hosts.yml
    echo "    git_protocol: https" >> /home/developer/.config/gh/hosts.yml
    chown -R developer:developer /home/developer/.config/gh
    chmod 600 /home/developer/.config/gh/hosts.yml
fi

# Configure Git credentials if provided
if [ ! -z "$GIT_USER_NAME" ]; then
    sudo -u developer git config --global user.name "$GIT_USER_NAME"
    echo "✅ Git user name configured: $GIT_USER_NAME"
fi

if [ ! -z "$GIT_USER_EMAIL" ]; then
    sudo -u developer git config --global user.email "$GIT_USER_EMAIL"
    echo "✅ Git user email configured: $GIT_USER_EMAIL"
fi

# Setup Git credential helper for GitHub token
if [ ! -z "$GITHUB_TOKEN" ]; then
    # Create credential helper script
    cat > /home/developer/.git-credential-helper.sh << 'EOF'
#!/bin/bash
# Git credential helper for GitHub token authentication

if [ "$1" = "get" ]; then
    while IFS= read -r line; do
        case "$line" in
            host=github.com)
                echo "protocol=https"
                echo "host=github.com"
                echo "username=token"
                echo "password=$GITHUB_TOKEN"
                break
                ;;
            host=*)
                # For non-GitHub hosts, exit without providing credentials
                exit 0
                ;;
        esac
    done
fi
EOF

    chmod +x /home/developer/.git-credential-helper.sh
    chown developer:developer /home/developer/.git-credential-helper.sh

    # Configure Git to use the credential helper
    sudo -u developer git config --global credential.helper "/home/developer/.git-credential-helper.sh"
    echo "✅ GitHub token authentication configured"
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