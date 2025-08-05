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