#!/bin/bash
set -e

# Create a welcome script for the developer user
# Create welcome script in /etc/skel so it gets copied to the persistent home
cat > /etc/skel/welcome.sh << 'EOF'
#!/bin/bash
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Welcome to Sindri - Your AI-Powered Development Forge!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 You are connected to: $(hostname)"
echo "💾 Workspace: /workspace"
echo "🔧 Available tools:"
echo "  - Git:"
git --version 2>/dev/null | sed 's/^/    /' || echo "    not installed"
echo "  - GitHub CLI:"
gh version 2>/dev/null | head -n1 | sed 's/^/    /' || echo "    not installed or not configured"
echo "  - jq:"
jq --version 2>/dev/null | sed 's/^/    /' || echo "    not installed"

echo ""
echo "📚 Next steps:"
echo "  1. Run configuration script: /workspace/scripts/vm-configure.sh"
echo "     This will:"
echo "     • Install Claude Code"
echo "     • Set up Git configuration"
echo "     • Create workspace structure"
echo "     • Install optional development tools"
echo "  2. Authenticate Claude: claude"
echo ""
echo "💡 Tip: All your work should be in /workspace (persistent volume)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
EOF

chmod +x /etc/skel/welcome.sh