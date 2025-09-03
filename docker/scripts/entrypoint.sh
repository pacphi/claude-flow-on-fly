#!/bin/bash
set -e

echo "🚀 Starting Claude Development Environment..."

# Ensure workspace exists and has correct permissions
echo "📁 Setting up workspace and developer home..."
if [ ! -d "/workspace" ]; then
    mkdir -p /workspace
fi

# Create developer home directory on persistent volume if it doesn't exist
if [ ! -d "/workspace/developer" ]; then
    echo "🏠 Creating developer home directory on persistent volume..."
    mkdir -p /workspace/developer
    # Copy skeleton files from /etc/skel
    if [ -d "/etc/skel" ]; then
        cp -r /etc/skel/. /workspace/developer/
    fi
    chown -R developer:developer /workspace/developer
    chmod 755 /workspace/developer
    echo "✅ Developer home directory created at /workspace/developer"
fi

# Update the user's home directory to point to persistent volume
echo "🔧 Updating user home directory..."
usermod -d /workspace/developer developer

# Ensure correct ownership of workspace
chown developer:developer /workspace
chmod 755 /workspace

# Create essential directories in workspace if they don't exist
sudo -u developer mkdir -p /workspace/projects
sudo -u developer mkdir -p /workspace/scripts
sudo -u developer mkdir -p /workspace/backups

# Configure SSH keys from environment variable
if [ ! -z "$AUTHORIZED_KEYS" ]; then
    echo "🔑 Configuring SSH keys..."
    mkdir -p /workspace/developer/.ssh
    echo "$AUTHORIZED_KEYS" > /workspace/developer/.ssh/authorized_keys
    chown -R developer:developer /workspace/developer/.ssh
    chmod 700 /workspace/developer/.ssh
    chmod 600 /workspace/developer/.ssh/authorized_keys
    echo "✅ SSH keys configured"
else
    echo "⚠️  No SSH keys found in AUTHORIZED_KEYS environment variable"
fi

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
    echo "export ANTHROPIC_API_KEY='$ANTHROPIC_API_KEY'" >> /workspace/developer/.bashrc
fi

# Configure GitHub token if provided
if [ ! -z "$GITHUB_TOKEN" ]; then
    echo "🔐 Configuring GitHub authentication..."
    echo "export GITHUB_TOKEN='$GITHUB_TOKEN'" >> /workspace/developer/.bashrc

    # Create GitHub CLI config for gh commands
    sudo -u developer mkdir -p /workspace/developer/.config/gh
    echo "github.com:" > /workspace/developer/.config/gh/hosts.yml
    echo "    oauth_token: $GITHUB_TOKEN" >> /workspace/developer/.config/gh/hosts.yml
    echo "    user: $GITHUB_USER" >> /workspace/developer/.config/gh/hosts.yml
    echo "    git_protocol: https" >> /workspace/developer/.config/gh/hosts.yml
    chown -R developer:developer /workspace/developer/.config/gh
    chmod 600 /workspace/developer/.config/gh/hosts.yml
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
    cat > /workspace/developer/.git-credential-helper.sh << 'EOF'
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

    chmod +x /workspace/developer/.git-credential-helper.sh
    chown developer:developer /workspace/developer/.git-credential-helper.sh

    # Configure Git to use the credential helper
    sudo -u developer git config --global credential.helper "/workspace/developer/.git-credential-helper.sh"
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