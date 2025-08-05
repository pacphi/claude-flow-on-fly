#!/bin/bash
set -e

# Install Node Version Manager (nvm) for flexible Node.js management
# This script should be run as the developer user

USER_HOME="/home/developer"
NVM_VERSION="v0.40.3"

# Download and install NVM
sudo -u developer bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"

# Create necessary directories for Claude tools
sudo -u developer mkdir -p $USER_HOME/.claude
sudo -u developer mkdir -p $USER_HOME/.config

# Set up Git configuration template (will be overridden by user)
sudo -u developer git config --global init.defaultBranch main
sudo -u developer git config --global pull.rebase false
sudo -u developer git config --global user.name "Developer"
sudo -u developer git config --global user.email "developer@example.com"