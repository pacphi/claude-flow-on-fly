#!/bin/bash
# Show system and development environment status

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

echo "🖥️  System Status"
echo "=================="
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disk: $(df -h /workspace | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo

echo "🔧 Development Tools"
echo "===================="
echo "Node.js: $(node --version 2>/dev/null || echo 'Not installed')"
echo "npm: $(npm --version 2>/dev/null || echo 'Not installed')"
echo "Python: $(python3 --version 2>/dev/null || echo 'Not installed')"
echo "Git: $(git --version 2>/dev/null || echo 'Not installed')"
echo "Claude Code: $(claude --version 2>/dev/null || echo 'Not installed/authenticated')"
echo "Claude Flow: $(command -v claude-flow >/dev/null && echo 'Installed' || echo 'Available via npx')"
echo

echo "📁 Workspace"
echo "============"
echo "Projects: $(find /workspace/projects -mindepth 1 -maxdepth 2 -type d 2>/dev/null | wc -l) directories"
echo "Backups: $(ls /workspace/backups/*.tar.gz 2>/dev/null | wc -l) files"
echo "Extensions: $(ls /workspace/scripts/extensions.d/*.sh 2>/dev/null | wc -l) scripts"
echo "Storage:"
df -h /workspace | awk 'NR==2 {print "  Used: " $3 " / " $2 " (" $5 ")"}'
echo

echo "🌐 Network"
echo "=========="
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "SSH Status: $(pgrep sshd >/dev/null && echo 'Running' || echo 'Not running')"

# Check for custom extensions
if [ -d "$EXTENSIONS_DIR" ] && [ "$(ls -A $EXTENSIONS_DIR/*.sh 2>/dev/null)" ]; then
    echo
    echo "🔌 Custom Extensions"
    echo "===================="
    for ext in "$EXTENSIONS_DIR"/*.sh; do
        [ -f "$ext" ] && echo "  - $(basename "$ext")"
    done
fi