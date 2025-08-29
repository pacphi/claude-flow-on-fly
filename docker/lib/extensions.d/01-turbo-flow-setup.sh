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

    # Copy TypeScript configuration from docker/config
    print_status "⚙️ Setting up TypeScript configuration..."
    if [[ -f "/docker/config/tsconfig.json" ]]; then
        cp /docker/config/tsconfig.json tsconfig.json
        print_success "✅ TypeScript configuration copied"
    else
        print_warning "⚠️ TypeScript configuration not found in /docker/config/"
    fi

    # Copy Playwright configuration from docker/config
    print_status "🧪 Setting up Playwright configuration..."
    if [[ -f "/docker/config/playwright.config.ts" ]]; then
        cp /docker/config/playwright.config.ts playwright.config.ts
        print_success "✅ Playwright configuration copied"
    else
        print_warning "⚠️ Playwright configuration not found in /docker/config/"
    fi

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

# Copy and setup aliases
create_aliases() {
    print_status "🔗 Setting up Turbo Flow aliases..."

    # Copy alias file from docker/config
    if [[ -f "/docker/config/turbo-flow-aliases" ]]; then
        cp /docker/config/turbo-flow-aliases "$WORKSPACE_DIR/.turbo-flow-aliases"
        print_success "✅ Turbo Flow aliases copied"
    else
        print_warning "⚠️ Turbo Flow aliases not found in /docker/config/"
    fi

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

# Copy setup validation script
create_setup_validation() {
    print_status "🔍 Installing setup validation script..."

    # Copy validation script from docker/lib
    if [[ -f "/docker/lib/validate-setup.sh" ]]; then
        cp /docker/lib/validate-setup.sh "$WORKSPACE_DIR/scripts/validate-setup.sh"
        chmod +x "$WORKSPACE_DIR/scripts/validate-setup.sh"
        print_success "✅ Setup validation script installed"
    else
        print_warning "⚠️ Setup validation script not found in /docker/lib/"
    fi
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