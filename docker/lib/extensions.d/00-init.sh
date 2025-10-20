#!/bin/bash
# 00-init.sh - Core Environment Initialization
# Consolidates: Turbo Flow, Agent Manager, Tmux Workspace, Context Management
# This script initializes all fundamental components of the development environment

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Check if libraries exist, fall back to docker location if needed
if [[ ! -d "$LIB_DIR" ]] && [[ -d "/docker/lib" ]]; then
    LIB_DIR="/docker/lib"
fi

source "$LIB_DIR/common.sh"

print_status "🚀 Initializing core development environment..."

# ============================================================================
# TURBO FLOW SETUP
# ============================================================================

# Install Playwright and dependencies
install_playwright() {
    print_status "🎭 Installing Playwright for visual verification..."

    # Ensure Node.js is installed first
    if ! command_exists node; then
        print_status "📦 Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs

        # Verify Node.js installation
        if ! command_exists node; then
            print_error "❌ Failed to install Node.js - Playwright cannot be installed"
            return 1
        fi

        print_success "✅ Node.js installed: $(node -v)"
    else
        print_status "✅ Node.js already installed: $(node -v)"
    fi

    # Verify npm is available
    if ! command_exists npm; then
        print_error "❌ npm is not available - cannot install Playwright"
        return 1
    fi

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

    # Install Playwright with explicit error handling
    print_status "🧪 Installing Playwright..."
    if npm install -D playwright @playwright/test; then
        print_success "✅ Playwright packages installed"
    else
        print_error "❌ Failed to install Playwright packages"
        return 1
    fi

    # Install Playwright browsers with better error handling
    print_status "🌐 Installing Playwright Chromium browser..."
    if npx playwright install chromium; then
        print_success "✅ Chromium browser installed"
    else
        print_warning "⚠️ Chromium browser installation had issues"
    fi

    print_status "🔧 Installing Chromium dependencies..."
    if npx playwright install-deps chromium; then
        print_success "✅ Chromium dependencies installed"
    else
        print_warning "⚠️ Chromium dependencies installation had issues"
    fi

    # Install TypeScript and build tools
    print_status "🔧 Installing TypeScript and development tools..."
    if npm install -D typescript @types/node; then
        print_success "✅ TypeScript tools installed"
    else
        print_warning "⚠️ TypeScript installation had issues"
    fi

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

    # Verify installation with detailed checking
    print_status "🔍 Verifying Playwright installation..."

    # Check if playwright binary exists in node_modules
    if [[ -f "node_modules/.bin/playwright" ]]; then
        print_success "✅ Playwright binary found"

        # Try to get version (with retries for CI environments)
        local max_attempts=3
        local attempt=1
        local pw_version="unknown"

        while [ $attempt -le $max_attempts ]; do
            if pw_version=$(npx playwright --version 2>/dev/null); then
                print_success "✅ Playwright installed and ready: $pw_version"
                return 0
            else
                if [ $attempt -lt $max_attempts ]; then
                    print_debug "Version check attempt $attempt failed, retrying..."
                    sleep 2
                    attempt=$((attempt + 1))
                else
                    print_warning "⚠️ Playwright binary exists but version check failed after $max_attempts attempts"
                    print_warning "This may work in normal use, but failed in current environment"
                    # Don't fail - Playwright is installed, version check just failed
                    return 0
                fi
            fi
        done
    else
        print_error "❌ Playwright binary not found in node_modules"
        return 1
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
        source $HOME/.local/bin/env
    fi

    # Install Claude Monitor using uv
    if command_exists uv; then
        uv tool install claude-monitor || {
            # Install pip3 as fallback if not available
            if ! command_exists pip3; then
                print_status "Installing python3-pip..."
                sudo apt-get update -qq && sudo apt-get install -y python3-pip
            fi
            pip3 install claude-monitor
        }
    else
        # Install pip3 if not available
        if ! command_exists pip3; then
            print_status "Installing python3-pip..."
            sudo apt-get update -qq && sudo apt-get install -y python3-pip
        fi
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

# ============================================================================
# AGENT MANAGER SETUP
# ============================================================================

# GitHub repository details
GITHUB_REPO="pacphi/claude-code-agent-manager"
BINARY_NAME="agent-manager"
INSTALL_PATH="$HOME/.local/bin"

# Function to get the latest release (including pre-releases)
get_latest_release() {
    local include_prereleases=${1:-false}
    local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases"

    if [[ "$include_prereleases" == "true" ]]; then
        # Get all releases (including pre-releases) and pick the first one
        curl -s "$api_url" | jq -r '.[0].tag_name' 2>/dev/null || echo ""
    else
        # Get only non-prerelease releases
        curl -s "$api_url" | jq -r '[.[] | select(.prerelease == false)][0].tag_name' 2>/dev/null || echo ""
    fi
}

# Function to download and install binary
install_agent_manager() {
    local tag_name="$1"

    if [[ -z "$tag_name" ]]; then
        print_error "No release tag found"
        return 1
    fi

    print_status "📥 Installing agent-manager version $tag_name..."

    # Detect platform and architecture
    local platform_arch
    case "$(uname -s)-$(uname -m)" in
        Linux-x86_64|Linux-amd64)
            platform_arch="linux-amd64"
            ;;
        Linux-aarch64|Linux-arm64)
            platform_arch="linux-arm64"
            ;;
        Darwin-x86_64|Darwin-amd64)
            platform_arch="darwin-amd64"
            ;;
        Darwin-arm64|Darwin-aarch64)
            platform_arch="darwin-arm64"
            ;;
        MINGW*-x86_64|MSYS*-x86_64|CYGWIN*-x86_64)
            platform_arch="windows-amd64"
            ;;
        *)
            print_error "Unsupported platform: $(uname -s)-$(uname -m)"
            return 1
            ;;
    esac

    local binary_name="${BINARY_NAME}-${platform_arch}"
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/${tag_name}/${binary_name}"

    print_status "🌐 Download URL: $download_url"

    # Create bin directory if it doesn't exist
    mkdir -p "$INSTALL_PATH"

    # Download the binary
    print_status "⬇️ Downloading agent-manager binary..."
    if curl -L -o "${INSTALL_PATH}/${BINARY_NAME}" "$download_url"; then
        print_success "✅ Binary downloaded successfully"
    else
        print_error "❌ Failed to download binary"
        return 1
    fi

    # Make executable
    chmod +x "${INSTALL_PATH}/${BINARY_NAME}"

    # Verify installation
    if "${INSTALL_PATH}/${BINARY_NAME}" version >/dev/null 2>&1; then
        local version
        version=$("${INSTALL_PATH}/${BINARY_NAME}" version 2>/dev/null | head -n1 || echo "unknown")
        print_success "✅ Agent Manager installed successfully: $version"
    else
        print_error "❌ Agent Manager installation failed - binary not working"
        return 1
    fi
}

# Function to setup agents configuration
setup_agents_config() {
    print_status "📝 Setting up agents configuration..."

    local config_dir="/workspace/config"
    local config_file="${config_dir}/agents-config.yaml"
    local template_file="/docker/config/agents-config.yaml"

    mkdir -p "$config_dir"

    # Check if user has already customized the config
    if [[ -f "$config_file" ]]; then
        print_status "📝 Agents config already exists, skipping template copy"
        print_status "💡 To reset: rm $config_file && rerun this script"
        return 0
    fi

    # Copy from template if it exists
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying agents config template..."
        cp "$template_file" "$config_file"
        print_success "✅ Agents configuration copied from template"
        print_status "📝 Edit $config_file to customize agent sources"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/agents-config.yaml exists."
        return 1
    fi

    # Make sure config is readable
    chmod 644 "$config_file"
    print_status "📁 Configuration location: $config_file"
}

# Function to add agent-manager to PATH
setup_agent_path() {
    print_status "🔗 Setting up PATH..."

    # Add to PATH in bashrc if not already there
    if ! grep -q "/workspace/bin" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Add workspace bin to PATH" >> "$HOME/.bashrc"
        echo 'export PATH="/workspace/bin:$PATH"' >> "$HOME/.bashrc"
        print_success "✅ Added /workspace/bin to PATH in .bashrc"
    fi

    # Export for current session
    export PATH="/workspace/bin:$PATH"
}

# Function to setup agent discovery utilities
setup_agent_discovery() {
    print_status "🔍 Setting up agent discovery utilities..."

    local discovery_script="/workspace/scripts/lib/agent-discovery.sh"
    local template_file="/docker/lib/agent-discovery.sh"

    # Ensure scripts/lib directory exists
    mkdir -p "/workspace/scripts/lib"

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying agent discovery script template..."
        cp "$template_file" "$discovery_script"
        chmod +x "$discovery_script"
        print_success "✅ Agent discovery utilities copied from template"

        # Source the discovery script for immediate availability
        source "$discovery_script"

        # Add sourcing to bashrc if not already present
        local bashrc_file="/workspace/developer/.bashrc"
        if [[ -f "$bashrc_file" ]]; then
            if ! grep -q "agent-discovery.sh" "$bashrc_file"; then
                print_status "📝 Adding agent-discovery.sh to .bashrc..."
                echo "" >> "$bashrc_file"
                echo "# Source agent discovery utilities" >> "$bashrc_file"
                echo "if [ -f /workspace/scripts/lib/agent-discovery.sh ]; then" >> "$bashrc_file"
                echo "    source /workspace/scripts/lib/agent-discovery.sh" >> "$bashrc_file"
                echo "fi" >> "$bashrc_file"
                print_success "✅ Added agent-discovery.sh to .bashrc"
            fi
        fi
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/agent-discovery.sh exists."
        return 1
    fi
}

# ============================================================================
# TMUX WORKSPACE SETUP
# ============================================================================

# Install tmux if not present
install_tmux() {
    if ! command_exists tmux; then
        print_status "📦 Installing tmux and monitoring tools..."
        sudo apt-get update -qq
        sudo apt-get install -y tmux htop
        print_success "✅ tmux and htop installed successfully"
    else
        print_status "✅ tmux already installed"
    fi
}

# Setup tmux configuration
setup_tmux_config() {
    print_status "⚙️ Setting up tmux configuration..."

    local config_file="/workspace/config/tmux.conf"
    local template_file="/docker/config/tmux.conf"

    # Create tmux config directory
    mkdir -p /workspace/config

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying tmux configuration template..."
        cp "$template_file" "$config_file"

        # Link to home directory for tmux to find
        ln -sf "$config_file" "$HOME/.tmux.conf"

        print_success "✅ Tmux configuration copied from template"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/tmux.conf exists."
        return 1
    fi
}

# Setup tmux workspace launcher
setup_workspace_launcher() {
    print_status "🚀 Setting up tmux workspace launcher..."

    local launcher_script="/workspace/scripts/tmux-workspace.sh"
    local template_file="/docker/lib/tmux-workspace.sh"

    # Ensure scripts directory exists
    mkdir -p /workspace/scripts

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying tmux workspace launcher template..."
        cp "$template_file" "$launcher_script"
        chmod +x "$launcher_script"
        print_success "✅ Tmux workspace launcher copied from template"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/tmux-workspace.sh exists."
        return 1
    fi
}

# Setup tmux helper functions
setup_tmux_helpers() {
    print_status "🔧 Setting up tmux helper functions..."

    local helpers_script="/workspace/scripts/lib/tmux-helpers.sh"
    local template_file="/docker/lib/tmux-helpers.sh"

    # Ensure scripts/lib directory exists
    mkdir -p /workspace/scripts/lib

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying tmux helpers template..."
        cp "$template_file" "$helpers_script"
        chmod +x "$helpers_script"
        print_success "✅ Tmux helper functions copied from template"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/tmux-helpers.sh exists."
        return 1
    fi
}

# Setup auto-start functionality
setup_auto_start() {
    print_status "🔄 Setting up auto-start functionality..."

    local auto_start_script="/workspace/scripts/tmux-auto-start.sh"
    local template_file="/docker/lib/tmux-auto-start.sh"

    # Ensure scripts directory exists
    mkdir -p /workspace/scripts

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying tmux auto-start template..."
        cp "$template_file" "$auto_start_script"
        chmod +x "$auto_start_script"
        print_success "✅ Tmux auto-start script copied from template"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/tmux-auto-start.sh exists."
        return 1
    fi
    # Add auto-start to bashrc (commented out by default)
    if ! grep -q "tmux-auto-start" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Auto-start tmux workspace (uncomment to enable)" >> "$HOME/.bashrc"
        echo "# source /workspace/scripts/tmux-auto-start.sh" >> "$HOME/.bashrc"
    fi

    print_success "✅ Auto-start functionality created (disabled by default)"
}

# ============================================================================
# CONTEXT MANAGEMENT SETUP
# ============================================================================

# Create context loading utilities
create_context_loader() {
    print_status "🔧 Creating context loading utilities..."

    local utilities_script="/workspace/scripts/lib/context-loader.sh"
    local template_file="/docker/lib/context-loader.sh"

    # Ensure scripts/lib directory exists
    mkdir -p "/workspace/scripts/lib"

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying context loader utilities template..."
        cp "$template_file" "$utilities_script"
        chmod +x "$utilities_script"
        print_success "✅ Context loading utilities copied from template"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/context-loader.sh exists."
        return 1
    fi
}

# Create Claude Flow context wrapper
create_cf_wrapper() {
    print_status "🔧 Creating Claude Flow context wrapper..."

    local wrapper_script="/workspace/scripts/cf-with-context.sh"
    local template_file="/docker/lib/cf-with-context.sh"

    # Ensure scripts directory exists
    mkdir -p /workspace/scripts

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying Claude Flow context wrapper template..."
        cp "$template_file" "$wrapper_script"
        chmod +x "$wrapper_script"
        print_success "✅ Claude Flow context wrapper copied from template"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/cf-with-context.sh exists."
        return 1
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_status "🎯 Core Environment Initialization"
    echo

    # Validate workspace
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        print_error "Workspace directory not found: $WORKSPACE_DIR"
        return 1
    fi

    # Create base directory structure
    print_status "📁 Creating directory structure..."
    create_project_structure

    # Install Turbo Flow components
    print_status "🎭 Setting up Turbo Flow..."
    install_playwright
    install_monitoring_tools
    create_setup_validation

    # Install Agent Manager
    print_status "🤖 Setting up Agent Manager..."

    # Check if curl and jq are available
    if ! command_exists curl; then
        print_error "curl is required but not installed"
        return 1
    fi

    if ! command_exists jq; then
        print_warning "jq not found, installing..."
        sudo apt-get update -qq && sudo apt-get install -y jq
    fi

    # Try to get latest release (including pre-releases first)
    print_status "🔍 Fetching latest release information..."
    local tag_name
    tag_name=$(get_latest_release true)

    if [[ -z "$tag_name" ]]; then
        # Fallback to stable releases only
        tag_name=$(get_latest_release false)
    fi

    if [[ -z "$tag_name" ]]; then
        print_error "Could not fetch release information from GitHub"
        return 1
    fi

    print_status "🏷️ Latest release: $tag_name"

    # Install the binary
    if install_agent_manager "$tag_name"; then
        setup_agent_path
        setup_agents_config
        setup_agent_discovery

        # Check if gh CLI is authenticated before trying to install agents
        if command_exists gh && gh auth status >/dev/null 2>&1; then
            # Try to install agents immediately
            print_status "🤖 Installing agents from configured sources..."
            if "${INSTALL_PATH}/${BINARY_NAME}" install --config /workspace/config/agents-config.yaml; then
                print_success "✅ Agents installed successfully!"
            else
                print_warning "⚠️ Agent installation failed - you can retry later with 'agent-install'"
            fi
        else
            print_warning "⚠️ GitHub CLI not authenticated - skipping automatic agent installation"
            print_status "To authenticate GitHub CLI and install agents:"
            print_status "  1. Set GitHub token: flyctl secrets set GITHUB_TOKEN=ghp_... -a <app-name>"
            print_status "  2. Re-run configuration: /workspace/scripts/vm-configure.sh"
            print_status "  3. Or manually: gh auth login && agent-install"
        fi
    else
        print_error "❌ Agent Manager installation failed"
        return 1
    fi

    # Setup Tmux Workspace
    print_status "🖥️  Setting up Tmux Workspace..."
    install_tmux
    setup_tmux_config
    setup_workspace_launcher
    setup_tmux_helpers
    setup_auto_start

    # Setup Context Management
    print_status "📚 Setting up Context Management..."
    create_context_loader
    create_cf_wrapper

    # Setup unified workspace aliases (shared function from common.sh)
    setup_workspace_aliases

    # Configure SSH daemon for non-interactive environment support
    print_status "🔐 Configuring SSH for non-interactive sessions..."
    configure_ssh_daemon_for_env

    # Reload SSH daemon to apply BASH_ENV configuration immediately
    # This ensures installed tools work in non-interactive SSH sessions (e.g., CI tests)
    print_status "🔄 Reloading SSH daemon to apply environment configuration..."
    if systemctl is-active --quiet ssh 2>/dev/null; then
        if sudo systemctl reload ssh 2>/dev/null; then
            print_success "✅ SSH daemon reloaded successfully"
        else
            print_warning "⚠️  Failed to reload SSH daemon (may require manual restart)"
        fi
    elif systemctl is-active --quiet sshd 2>/dev/null; then
        if sudo systemctl reload sshd 2>/dev/null; then
            print_success "✅ SSH daemon (sshd) reloaded successfully"
        else
            print_warning "⚠️  Failed to reload SSH daemon (may require manual restart)"
        fi
    else
        print_warning "⚠️  SSH daemon not running or not using systemd"
        print_status "💡 Environment will be available after next SSH session"
    fi

    print_success "🎉 Core environment initialization completed!"
    echo
    print_status "📋 Installed Systems:"
    echo "  • Turbo Flow: Playwright, monitoring, validation"
    echo "  • Agent Manager: agent-install, agent-list, agent-update"
    echo "  • Tmux Workspace: tmux-workspace, tmux-* commands"
    echo "  • Context Management: load-context, cf-swarm, validate-context"
    echo
    print_status "🔍 Validation:"
    echo "  • Run: /workspace/scripts/validate-setup.sh"
    echo
    print_status "📖 Quick Start:"
    echo "  1. Authenticate Claude: claude"
    echo "  2. Start tmux workspace: tmux-workspace"
    echo "  3. Install agents: agent-install"
    echo "  4. Load context: load-context"
}

# Execute main function
main "$@"
