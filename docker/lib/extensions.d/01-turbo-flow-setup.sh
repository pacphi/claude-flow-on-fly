#!/bin/bash
# 01-turbo-flow-setup.sh - Turbo Flow Claude Setup Extension
# Installs Playwright, TypeScript configuration, aliases, and verification tools

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Check if libraries exist, fall back to docker location if needed
if [[ ! -d "$LIB_DIR" ]] && [[ -d "/docker/lib" ]]; then
    LIB_DIR="/docker/lib"
fi

source "$LIB_DIR/common.sh"

print_status "🔧 Installing Turbo Flow Claude enhancements..."

# Install Playwright and dependencies
install_playwright() {
    print_status "🎭 Installing Playwright for visual verification..."

    # Ensure we're in workspace directory
    cd "$WORKSPACE_DIR" || return 1

    # Initialize package.json if it doesn't exist
    if [[ ! -f "package.json" ]]; then
        print_status "📦 Initializing Node.js project..."
        npm init -y
    fi

    # Fix TypeScript module configuration
    print_status "🔧 Setting up ES modules..."
    npm pkg set type="module"

    # Install Playwright
    print_status "🧪 Installing Playwright..."
    npm install -D playwright @playwright/test

    # Install Playwright browsers
    npx playwright install chromium
    npx playwright install-deps chromium

    # Install TypeScript and build tools
    print_status "🔧 Installing TypeScript and development tools..."
    npm install -D typescript @types/node

    # Create TypeScript configuration for ES modules
    print_status "⚙️ Creating TypeScript configuration..."
    cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "node",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true
  },
  "include": ["src/**/*", "tests/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

    # Create Playwright configuration
    print_status "🧪 Creating Playwright configuration..."
    cat > playwright.config.ts << 'EOF'
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  use: {
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { channel: 'chromium' },
    },
  ],
});
EOF

    # Create basic test example
    print_status "📝 Creating example test..."
    mkdir -p tests
    cat > tests/example.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test('environment validation', async ({ page }) => {
  // Basic test to verify Playwright works
  expect(true).toBe(true);
});
EOF

    # Update package.json with essential scripts
    print_status "📝 Adding essential npm scripts..."
    npm pkg set scripts.build="tsc"
    npm pkg set scripts.test="playwright test"
    npm pkg set scripts.lint="echo 'Add linting here'"
    npm pkg set scripts.typecheck="tsc --noEmit"
    npm pkg set scripts.playwright="playwright test"

    # Verify installation
    if npx playwright --version >/dev/null 2>&1; then
        print_success "✅ Playwright installed and ready for visual verification"
    else
        print_warning "⚠️ Playwright installation may have issues"
    fi
}

# Install Claude monitoring tools
install_monitoring_tools() {
    print_status "📊 Installing Claude monitoring tools..."

    # Install UV package manager if not present
    if ! command_exists uv; then
        print_status "Installing UV package manager..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        if [[ -f "$HOME/.cargo/env" ]]; then
            source "$HOME/.cargo/env"
        else
            export PATH="$HOME/.cargo/bin:$PATH"
        fi
    fi

    # Install Claude Monitor using uv
    if command_exists uv; then
        uv tool install claude-monitor || pip3 install claude-monitor
    else
        pip3 install claude-monitor
    fi

    # Install claude-usage-cli
    npm install -g claude-usage-cli || print_warning "Failed to install claude-usage-cli"

    # Verify Claude Monitor installation
    if command_exists claude-monitor; then
        print_success "✅ Claude Monitor installed successfully"
    else
        print_warning "❌ Claude Monitor installation failed"
    fi
}

# Create essential directories
create_project_structure() {
    print_status "📁 Creating enhanced project directories..."

    cd "$WORKSPACE_DIR" || return 1

    # Create directories required by turbo-flow methodology
    mkdir -p src tests docs scripts examples config
    mkdir -p agents context bin backups

    # Create subdirectories for context management
    mkdir -p context/global context/templates
    mkdir -p scripts/lib scripts/extensions.d
    mkdir -p config/templates

    print_success "✅ Project structure created"
}

# Create comprehensive aliases
create_aliases() {
    print_status "🔗 Creating Turbo Flow aliases..."

    # Create alias file that can be sourced
    cat > "$WORKSPACE_DIR/.turbo-flow-aliases" << 'EOF'
# Turbo Flow Claude Aliases

# Claude Code shortcuts
alias dsp="claude --dangerously-skip-permissions"
alias cf-dsp="claude --dangerously-skip-permissions"

# Claude Flow commands (will be enhanced with context wrapper later)
alias cf-init="npx claude-flow@alpha init --verify --pair --github-enhanced"
alias cf-verify="npx claude-flow@alpha verify"
alias cf-truth="npx claude-flow@alpha truth"
alias cf-pair="npx claude-flow@alpha pair --start"

# Agent discovery helpers
alias agent-count="find /workspace/agents -name '*.md' 2>/dev/null | wc -l"
alias agent-sample="find /workspace/agents -name '*.md' 2>/dev/null | shuf | head -10"
alias agent-search="find /workspace/agents -name"

# Context management
alias load-context="cat /workspace/context/global/CLAUDE.md /workspace/context/global/FEEDCLAUDE.md /workspace/context/global/CCFOREVER.md 2>/dev/null || echo 'Context files not found'"

# Project helpers
alias new-project="/workspace/scripts/lib/new-project.sh"
alias project-status="/workspace/scripts/lib/system-status.sh"

# Monitoring
alias claude-usage="claude-usage-cli"
alias monitor-claude="claude-monitor"

EOF

    # Add sourcing to bashrc if not already there
    if ! grep -q "turbo-flow-aliases" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Source Turbo Flow aliases" >> "$HOME/.bashrc"
        echo "if [[ -f /workspace/.turbo-flow-aliases ]]; then" >> "$HOME/.bashrc"
        echo "    source /workspace/.turbo-flow-aliases" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
    fi

    print_success "✅ Aliases created and configured"
}

# Create basic setup validation
create_setup_validation() {
    print_status "🔍 Creating setup validation script..."

    # Create basic validation script
    cat > "$WORKSPACE_DIR/scripts/validate-setup.sh" << 'EOF'
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
EOF

    chmod +x "$WORKSPACE_DIR/scripts/validate-setup.sh"
    print_success "✅ Setup validation script created"
}

# Main execution
main() {
    print_status "🚀 Starting Turbo Flow setup..."

    # Ensure we have workspace directory
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        print_error "Workspace directory not found: $WORKSPACE_DIR"
        return 1
    fi

    # Install components
    create_project_structure
    install_playwright
    install_monitoring_tools
    create_aliases
    create_setup_validation

    print_success "🎉 Turbo Flow setup completed successfully!"
    print_status "Run '/workspace/scripts/validate-setup.sh' to validate installation"
}

# Execute main function
main "$@"