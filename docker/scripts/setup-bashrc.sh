#!/bin/bash
set -e

# This script sets up the developer user's bash environment
USER_HOME="/home/developer"

# Create SSH directory with proper permissions
sudo -u developer mkdir -p $USER_HOME/.ssh
chmod 700 $USER_HOME/.ssh
sudo -u developer touch $USER_HOME/.ssh/authorized_keys
chmod 600 $USER_HOME/.ssh/authorized_keys

# Create .bashrc with useful aliases and environment setup
cat >> $USER_HOME/.bashrc << 'EOF'

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

# NVM setup (will be configured by install-nvm.sh)
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

# Ensure proper ownership
chown developer:developer $USER_HOME/.bashrc