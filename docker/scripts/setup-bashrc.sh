#!/bin/bash
set -e

# This script sets up the initial bashrc that will be used as a template
# The actual home directory will be created on the persistent volume during runtime

# Create the bashrc content and save it to /etc/skel so it gets copied
# to the developer home when created
cat >> /etc/skel/.bashrc << 'EOF'

# Custom aliases and functions
alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"
alias ..="cd .."
alias ...="cd ../.."
alias gs="git status"
alias gp="git push"
alias gl="git log --oneline"

# Set a fancy prompt
PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "

# Change to workspace by default
cd /workspace

# NVM setup
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Source agent discovery utilities if available
if [ -f /workspace/scripts/lib/agent-discovery.sh ]; then
    source /workspace/scripts/lib/agent-discovery.sh
fi

# Source agent aliases if available
if [ -f /workspace/.agent-aliases ]; then
    source /workspace/.agent-aliases
fi

# Show welcome message on first login
if [ ! -f ~/.welcome_shown ]; then
    [ -f ~/welcome.sh ] && ~/welcome.sh
    touch ~/.welcome_shown
fi
EOF

# Create necessary directories in /etc/skel for Claude tools
# These will be copied to the persistent home directory during entrypoint.sh
mkdir -p /etc/skel/.claude
mkdir -p /etc/skel/.config

# Set up basic Git configuration (will be available system-wide)
git config --system init.defaultBranch main 2>/dev/null || true
git config --system pull.rebase false 2>/dev/null || true
git config --system user.name "Developer" 2>/dev/null || true
git config --system user.email "developer@example.com" 2>/dev/null || true

# Note: The .bashrc file will be copied from /etc/skel to the developer home
# directory during entrypoint.sh execution when the persistent volume is mounted