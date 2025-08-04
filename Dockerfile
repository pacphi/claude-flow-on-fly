FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set locale to prevent locale warnings
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # SSH and user management
    openssh-server \
    sudo \
    # Development tools
    curl \
    wget \
    git \
    vim \
    nano \
    tmux \
    screen \
    htop \
    tree \
    jq \
    unzip \
    # Build tools
    build-essential \
    pkg-config \
    # Languages and runtimes
    python3 \
    python3-pip \
    python3-venv \
    nodejs \
    npm \
    # Additional useful tools
    sqlite3 \
    postgresql-client \
    redis-tools \
    # Network and debugging tools
    net-tools \
    iputils-ping \
    telnet \
    netcat \
    # File utilities
    rsync \
    zip \
    unzip \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create developer user with sudo privileges
RUN useradd -m -s /bin/bash -G sudo developer && \
    echo "developer:developer" | chpasswd && \
    echo "developer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer

# Configure SSH daemon
RUN mkdir -p /var/run/sshd && \
    # Disable root login
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    # Disable password authentication (key-only)
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    # Enable public key authentication
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    # Keep connections alive
    echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config

# Create and configure workspace directory (will be mounted as volume)
RUN mkdir -p /workspace && \
    chown developer:developer /workspace && \
    chmod 755 /workspace

# Create scripts directory in workspace
RUN mkdir -p /workspace/scripts && \
    chown developer:developer /workspace/scripts

# Switch to developer user for remaining setup
USER developer
WORKDIR /home/developer

# Create SSH directory with proper permissions
RUN mkdir -p ~/.ssh && \
    chmod 700 ~/.ssh && \
    touch ~/.ssh/authorized_keys && \
    chmod 600 ~/.ssh/authorized_keys

# Create .bashrc with useful aliases and environment setup
RUN echo '# Custom aliases and functions' >> ~/.bashrc && \
    echo 'alias ll="ls -alF"' >> ~/.bashrc && \
    echo 'alias la="ls -A"' >> ~/.bashrc && \
    echo 'alias l="ls -CF"' >> ~/.bashrc && \
    echo 'alias ..="cd .."' >> ~/.bashrc && \
    echo 'alias ...="cd ../.."' >> ~/.bashrc && \
    echo 'alias gs="git status"' >> ~/.bashrc && \
    echo 'alias gp="git push"' >> ~/.bashrc && \
    echo 'alias gl="git log --oneline"' >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo '# Set a fancy prompt' >> ~/.bashrc && \
    echo 'PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> ~/.bashrc && \
    echo '' >> ~/.bashrc && \
    echo '# Change to workspace by default' >> ~/.bashrc && \
    echo 'cd /workspace' >> ~/.bashrc

# Install Node Version Manager (nvm) for flexible Node.js management
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc

# Create necessary directories for Claude tools
RUN mkdir -p ~/.claude && \
    mkdir -p ~/.config

# Set up Git configuration template (will be overridden by user)
RUN git config --global init.defaultBranch main && \
    git config --global pull.rebase false && \
    git config --global user.name "Developer" && \
    git config --global user.email "developer@example.com"

# Create a welcome script
RUN echo '#!/bin/bash' > ~/welcome.sh && \
    echo 'echo "🚀 Welcome to your Claude Development Environment!"' >> ~/welcome.sh && \
    echo 'echo "📍 You are connected to: $(hostname)"' >> ~/welcome.sh && \
    echo 'echo "💾 Workspace: /workspace"' >> ~/welcome.sh && \
    echo 'echo "🔧 Available tools:"' >> ~/welcome.sh && \
    echo 'echo "  - Git: $(git --version)"' >> ~/welcome.sh && \
    echo 'echo "  - Python: $(python3 --version)"' >> ~/welcome.sh && \
    echo 'echo "  - Node.js: \$(node --version 2>/dev/null || echo \"Not installed (use nvm)\")"' >> ~/welcome.sh && \
    echo 'echo ""' >> ~/welcome.sh && \
    echo 'echo "📚 Next steps:"' >> ~/welcome.sh && \
    echo 'echo "  1. Run configuration script: /workspace/scripts/vm-configure.sh"' >> ~/welcome.sh && \
    echo 'echo "     This will:"' >> ~/welcome.sh && \
    echo 'echo "     • Install Node.js and Claude Code"' >> ~/welcome.sh && \
    echo 'echo "     • Set up Git configuration"' >> ~/welcome.sh && \
    echo 'echo "     • Create workspace structure"' >> ~/welcome.sh && \
    echo 'echo "     • Install optional development tools"' >> ~/welcome.sh && \
    echo 'echo "  2. Authenticate Claude: claude"' >> ~/welcome.sh && \
    echo 'echo ""' >> ~/welcome.sh && \
    echo 'echo "💡 Tip: All your work should be in /workspace (persistent volume)"' >> ~/welcome.sh && \
    chmod +x ~/welcome.sh

# Add welcome script to bashrc
RUN echo '' >> ~/.bashrc && \
    echo '# Show welcome message on first login' >> ~/.bashrc && \
    echo 'if [ ! -f ~/.welcome_shown ]; then' >> ~/.bashrc && \
    echo '    ~/welcome.sh' >> ~/.bashrc && \
    echo '    touch ~/.welcome_shown' >> ~/.bashrc && \
    echo 'fi' >> ~/.bashrc

# Switch back to root for system-level startup configuration
USER root

# Create comprehensive startup script
RUN cat > /start.sh << 'EOF'
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

# Create helpful scripts in workspace
if [ ! -f "/workspace/scripts/install-claude-tools.sh" ]; then
    cat > /workspace/scripts/install-claude-tools.sh << 'SCRIPT_EOF'
#!/bin/bash
# Install Claude development tools

echo "🔧 Installing Claude development tools..."

# Load NVM
source ~/.nvm/nvm.sh

# Install latest LTS Node.js
echo "📦 Installing Node.js LTS..."
nvm install --lts
nvm use --lts
nvm alias default lts/*

# Install Claude Code
echo "🤖 Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

# Note: Claude Flow is not installed globally - it's run via npx

# Verify installations
echo "✅ Verifying installations..."
echo "Node.js: $(node --version)"
echo "NPM: $(npm --version)"
echo "Claude Code: $(claude --version 2>/dev/null || echo 'Not authenticated yet')"

echo "🎉 Installation complete!"
echo "💡 Next steps:"
echo "   1. Authenticate Claude: claude"
echo "   2. Initialize a Claude Flow project: npx claude-flow@alpha init --force"
echo "   3. Use Claude Flow: npx claude-flow@alpha swarm 'your task'"
SCRIPT_EOF
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
EOF

# Make startup script executable
RUN chmod +x /start.sh

# Copy the vm-configure.sh script to the VM
COPY scripts/vm-configure.sh /workspace/scripts/vm-configure.sh
RUN chown developer:developer /workspace/scripts/vm-configure.sh && \
    chmod +x /workspace/scripts/vm-configure.sh

# Create a health check script
RUN echo '#!/bin/bash' > /health.sh && \
    echo 'if pgrep sshd > /dev/null; then' >> /health.sh && \
    echo '    exit 0' >> /health.sh && \
    echo 'else' >> /health.sh && \
    echo '    exit 1' >> /health.sh && \
    echo 'fi' >> /health.sh && \
    chmod +x /health.sh

# Expose SSH port
EXPOSE 22

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /health.sh

# Use startup script as entry point
CMD ["/start.sh"]