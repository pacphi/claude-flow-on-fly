#!/bin/bash
# Basic validation script for Turbo Flow setup

echo "🔍 Validating Turbo Flow Setup..."
echo "================================="

# Check Node.js and npm
echo -n "Node.js: "
node --version 2>/dev/null || echo "❌ Not installed"

echo -n "npm: "
npm --version 2>/dev/null || echo "❌ Not installed"

# Check Playwright
echo -n "Playwright: "
npx playwright --version 2>/dev/null || echo "❌ Not installed"

# Check Claude tools
echo -n "Claude Code: "
command -v claude >/dev/null && echo "✅ Installed" || echo "❌ Not installed"

echo -n "Claude Flow: "
npx claude-flow@alpha --version 2>/dev/null >/dev/null && echo "✅ Available" || echo "❌ Not available"

# Check monitoring tools
echo -n "Claude Monitor: "
command -v claude-monitor >/dev/null && echo "✅ Installed" || echo "❌ Not installed"

echo -n "Claude Usage CLI: "
command -v claude-usage-cli >/dev/null && echo "✅ Installed" || echo "❌ Not installed"

# Check directory structure
echo ""
echo "Directory Structure:"
for dir in agents context bin scripts config; do
    if [[ -d "/workspace/$dir" ]]; then
        echo "✅ /workspace/$dir"
    else
        echo "❌ /workspace/$dir (missing)"
    fi
done

echo ""
echo "Validation complete!"