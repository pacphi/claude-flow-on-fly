#!/bin/bash
# 03-tmux-workspace.sh - Tmux Workspace Setup Extension
# Creates multi-window tmux environment for Claude development

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")"

# Check if libraries exist, fall back to workspace location if needed
if [[ ! -f "$LIB_DIR/common.sh" ]] && [[ -f "/workspace/scripts/lib/common.sh" ]]; then
    LIB_DIR="/workspace/scripts/lib"
fi

source "$LIB_DIR/common.sh"

print_status "📺 Setting up Tmux workspace environment..."

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

# Setup tmux aliases
setup_tmux_aliases() {
    print_status "🔗 Setting up tmux aliases..."

    local aliases_file="/workspace/.tmux-aliases"
    local template_file="/docker/config/tmux-aliases"

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying tmux aliases template..."
        cp "$template_file" "$aliases_file"
        print_success "✅ Tmux aliases copied from template"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/tmux-aliases exists."
        return 1
    fi
    # Add sourcing to bashrc if not already there
    if ! grep -q "tmux-aliases" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Source tmux workspace aliases" >> "$HOME/.bashrc"
        echo "if [[ -f /workspace/.tmux-aliases ]]; then" >> "$HOME/.bashrc"
        echo "    source /workspace/.tmux-aliases" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
    fi

    print_success "✅ Tmux aliases created and configured"
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

# Main execution
main() {
    print_status "🚀 Setting up Tmux workspace environment..."

    # Ensure workspace directory exists
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        print_error "Workspace directory not found: $WORKSPACE_DIR"
        return 1
    fi

    # Create directories
    mkdir -p /workspace/scripts/lib

    # Install and configure
    install_tmux
    setup_tmux_config
    setup_workspace_launcher
    setup_tmux_helpers
    setup_tmux_aliases
    setup_auto_start

    print_success "🎉 Tmux workspace setup completed successfully!"
    print_status "📋 Usage:"
    print_status "  tmux-workspace        # Start/attach to workspace"
    print_status "  tmux-workspace --new  # Force create new session"
    print_status "  tmux-status           # Show session status"
    print_status "  tmux-cleanup          # Clean up old sessions"
    print_status ""
    print_status "🔧 To enable auto-start on SSH, edit ~/.bashrc and uncomment the tmux-auto-start line"
}

# Execute main function
main "$@"
