#!/bin/bash
# 02-agent-manager.sh - Agent Manager Installation Extension
# Downloads and installs claude-code-agent-manager binary from GitHub releases

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../lib"

# Check if libraries exist, fall back to docker location if needed
if [[ ! -d "$LIB_DIR" ]] && [[ -d "/docker/lib" ]]; then
    LIB_DIR="/docker/lib"
fi

source "$LIB_DIR/common.sh"

# GitHub repository details
GITHUB_REPO="pacphi/claude-code-agent-manager"
BINARY_NAME="agent-manager"
INSTALL_PATH="/workspace/bin"

print_status "🤖 Installing Claude Code Agent Manager..."

# Function to get the latest release (including pre-releases)
get_latest_release() {
    local include_prereleases=${1:-false}
    local api_url="https://api.github.com/repos/${GITHUB_REPO}/releases"

    print_status "🔍 Fetching latest release information..."

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

    # Detect architecture
    local arch
    case "$(uname -m)" in
        x86_64|amd64)
            arch="x86_64"
            ;;
        aarch64|arm64)
            arch="aarch64"
            ;;
        *)
            print_error "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac

    # Detect OS
    local os
    case "$(uname -s)" in
        Linux)
            os="unknown-linux-gnu"
            ;;
        Darwin)
            os="apple-darwin"
            ;;
        *)
            print_error "Unsupported OS: $(uname -s)"
            return 1
            ;;
    esac

    local binary_name="${BINARY_NAME}-${arch}-${os}"
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
    if "${INSTALL_PATH}/${BINARY_NAME}" --version >/dev/null 2>&1; then
        local version
        version=$("${INSTALL_PATH}/${BINARY_NAME}" --version 2>/dev/null | head -n1 || echo "unknown")
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
    local template_file="/docker/templates/agents-config.yaml"

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
setup_path() {
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

# Function to setup agent management aliases
setup_agent_aliases() {
    print_status "🔗 Setting up agent management aliases..."

    local aliases_file="/workspace/.agent-aliases"
    local template_file="/docker/templates/agent-aliases"

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying agent aliases template..."
        cp "$template_file" "$aliases_file"
        print_success "✅ Agent aliases copied from template"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/agent-aliases exists."
        return 1
    fi

    # Add sourcing to bashrc if not already there
    if ! grep -q "agent-aliases" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Source agent management aliases" >> "$HOME/.bashrc"
        echo "if [[ -f /workspace/.agent-aliases ]]; then" >> "$HOME/.bashrc"
        echo "    source /workspace/.agent-aliases" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
    fi

    print_success "✅ Agent aliases created and configured"
}

# Function to setup agent discovery utilities
setup_agent_discovery() {
    print_status "🔍 Setting up agent discovery utilities..."

    local discovery_script="/workspace/scripts/lib/agent-discovery.sh"
    local template_file="/docker/templates/agent-discovery.sh"

    # Ensure scripts/lib directory exists
    mkdir -p "/workspace/scripts/lib"

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying agent discovery script template..."
        cp "$template_file" "$discovery_script"
        chmod +x "$discovery_script"
        print_success "✅ Agent discovery utilities copied from template"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/agent-discovery.sh exists."
        return 1
    fi
}

# Main execution
main() {
    print_status "🚀 Installing Claude Code Agent Manager..."

    # Check if curl and jq are available
    if ! command_exists curl; then
        print_error "curl is required but not installed"
        return 1
    fi

    if ! command_exists jq; then
        print_warning "jq not found, installing..."
        apt-get update -qq && apt-get install -y jq
    fi

    # Try to get latest release (including pre-releases first)
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
        setup_path
        setup_agents_config
        setup_agent_aliases
        setup_agent_discovery

        print_success "🎉 Agent Manager installation completed successfully!"
        print_status "📋 Next steps:"
        print_status "  1. Run 'agent-manager install' to install agents"
        print_status "  2. Run 'agent-list' to see installed agents"
        print_status "  3. Use 'agent-find <term>' to search for specific agents"

        # Try to install agents immediately
        print_status "🤖 Installing agents from configured sources..."
        if "${INSTALL_PATH}/${BINARY_NAME}" install; then
            print_success "✅ Agents installed successfully!"
        else
            print_warning "⚠️ Agent installation failed - you can retry later with 'agent-install'"
        fi

    else
        print_error "❌ Agent Manager installation failed"
        return 1
    fi
}

# Execute main function
main "$@"