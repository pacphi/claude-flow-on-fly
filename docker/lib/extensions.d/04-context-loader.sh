#!/bin/bash
# 04-context-loader.sh - Context Management System Extension
# Deploys three-tier context system (CLAUDE.md, FEEDCLAUDE.md, CCFOREVER.md)

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")"

# Check if libraries exist, fall back to workspace location if needed
if [[ ! -f "$LIB_DIR/common.sh" ]] && [[ -f "/workspace/scripts/lib/common.sh" ]]; then
    LIB_DIR="/workspace/scripts/lib"
fi

source "$LIB_DIR/common.sh"

print_status "📚 Setting up Context Management System..."

mkdir -p /workspace/context/global


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

# Create context aliases
create_context_aliases() {
    print_status "🔗 Creating context management aliases..."

    local aliases_file="/workspace/.context-aliases"
    local template_file="/docker/config/context-aliases"

    # Copy from template - fail if not found
    if [[ -f "$template_file" ]]; then
        print_status "📋 Copying context aliases template..."
        cp "$template_file" "$aliases_file"
        print_success "✅ Context aliases copied from template"
    else
        print_error "❌ Template not found at $template_file"
        print_error "Required template file is missing. Please ensure templates/context-aliases exists."
        return 1
    fi

    # Add sourcing to bashrc if not already there
    if ! grep -q "context-aliases" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# Source context management aliases" >> "$HOME/.bashrc"
        echo "if [[ -f /workspace/.context-aliases ]]; then" >> "$HOME/.bashrc"
        echo "    source /workspace/.context-aliases" >> "$HOME/.bashrc"
        echo "fi" >> "$HOME/.bashrc"
    fi

    print_success "✅ Context aliases created and configured"
}

# Main execution
main() {
    print_status "🚀 Setting up Context Management System..."

    # Create directory structure
    mkdir -p /workspace/context/global
    mkdir -p /workspace/context/templates
    mkdir -p /workspace/scripts/lib
    mkdir -p "$HOME/.claude"


    # Create utilities and wrappers
    create_context_loader
    create_cf_wrapper
    create_context_aliases

    print_success "🎉 Context Management System setup completed!"
    print_status "📋 Available commands:"
    print_status "  load-context           # View all context"
    print_status "  validate-context       # Validate context files"
    print_status "  context-hierarchy      # Show loading hierarchy"
    print_status "  cf swarm '<task>'      # Claude Flow with context"
}

# Execute main function
main "$@"