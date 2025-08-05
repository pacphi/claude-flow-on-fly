#!/bin/bash
set -e

# Create a welcome script for the developer user
USER_HOME="/home/developer"

cat > $USER_HOME/welcome.sh << 'EOF'
#!/bin/bash
echo "🚀 Welcome to your Claude Development Environment!"
echo "📍 You are connected to: $(hostname)"
echo "💾 Workspace: /workspace"
echo "🔧 Available tools:"
echo "  - Git: $(git --version)"
echo "  - Python: $(python3 --version)"
echo "  - Node.js: $(node --version 2>/dev/null || echo "Not installed (use nvm)")"
echo ""
echo "📚 Next steps:"
echo "  1. Run configuration script: /workspace/scripts/vm-configure.sh"
echo "     This will:"
echo "     • Install Node.js and Claude Code"
echo "     • Set up Git configuration"
echo "     • Create workspace structure"
echo "     • Install optional development tools"
echo "  2. Authenticate Claude: claude"
echo ""
echo "💡 Tip: All your work should be in /workspace (persistent volume)"
EOF

chmod +x $USER_HOME/welcome.sh
chown developer:developer $USER_HOME/welcome.sh