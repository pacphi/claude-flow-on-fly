#!/bin/bash
# vm-configure.sh - Configuration script for Sindri
# This script runs ON the Fly.io VM to configure the AI-powered development forge

set -e  # Exit on any error

# Source common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Check if libraries exist, fall back to docker location if needed
if [[ ! -d "$LIB_DIR" ]] && [[ -d "/docker/lib" ]]; then
    LIB_DIR="/docker/lib"
fi

# Source libraries
source "$LIB_DIR/common.sh"
source "$LIB_DIR/workspace.sh"
source "$LIB_DIR/tools.sh"
source "$LIB_DIR/git.sh"
source "$LIB_DIR/gh.sh"

# Function to show environment status
show_environment_status() {
    echo
    print_success "🎉 Environment Ready!"
    echo
    print_status "📋 Summary:"
    echo "  • Workspace: $WORKSPACE_DIR"
    echo "  • Node.js: $(node --version 2>/dev/null || echo 'Not installed')"
    echo "  • npm: $(npm --version 2>/dev/null || echo 'Not installed')"
    echo "  • Claude Code: $(command_exists claude && echo "Installed" || echo "Installation failed")"
    echo "  • Claude Flow: Available via npx"
    echo "  • Git: $(git config --global user.name 2>/dev/null || echo 'Not configured') <$(git config --global user.email 2>/dev/null || echo 'Not configured')>"
    echo "  • GitHub CLI: $(command_exists gh && gh --version 2>/dev/null | head -n1 || echo 'Not installed')"
    echo "  • GitHub Auth: $(gh auth status >/dev/null 2>&1 && echo "Authenticated" || echo "Not authenticated")"
    echo
    print_status "🤖 Features:"
    echo "  • Agent Manager: $(test -x /workspace/bin/agent-manager && echo "Ready" || echo "Not installed")"
    echo "  • Agents Available: $(find /workspace/agents -name '*.md' 2>/dev/null | wc -l | tr -d ' ') agents"
    echo "  • Context System: $(test -f /workspace/context/global/CLAUDE.md && echo "Ready" || echo "Not configured")"
    echo "  • Tmux Workspace: $(command_exists tmux && echo "Ready" || echo "Not installed")"
    echo "  • Setup Validation: $(test -f /workspace/scripts/validate-setup.sh && echo "Ready" || echo "Not configured")"
    echo "  • Playwright Testing: $(npx playwright --version 2>/dev/null && echo "Ready" || echo "Not installed")"
    echo
    print_status "🔧 Quick Commands:"
    echo "  • agent-install              # Install all agents"
    echo "  • agent-list                 # List available agents"
    echo "  • tmux-workspace             # Start development environment"
    echo "  • cf-swarm '<task>'          # Claude Flow with context"
    echo "  • load-context               # View all context files"
    echo "  • validate-context           # Validate context system"
    echo
    print_status "🔍 Validation:"
    echo "  • /workspace/scripts/validate-setup.sh - Basic setup validation"
    echo
    print_status "📁 Project Structure:"
    echo "  • $PROJECTS_DIR/active/ - Active projects"
    echo "  • $PROJECTS_DIR/archive/ - Archived projects"
    echo "  • $PROJECTS_DIR/templates/ - Project templates"
    echo "  • /workspace/agents/ - Claude Code agents"
    echo "  • /workspace/context/ - Context management files"
    echo
    print_status "🚀 Getting Started:"
    echo "  1. Authenticate Claude: claude"
    echo "  2. Start tmux workspace: tmux-workspace"
    echo "  3. Validate setup: /workspace/scripts/validate-setup.sh"
    echo "  4. Create a project: new-project my-app node"
    echo "  5. Begin development with AI assistance!"
}

# Function to run configuration prompts
run_interactive_setup() {
    echo "🔧 Interactive Configuration Setup"
    echo "=================================="
    echo

    # Git configuration
    setup_git

    # Optional: Set up additional tools
    echo
    if confirm "Install additional development tools? (eslint, prettier, etc.)" "n"; then
        install_dev_tools
    fi

    echo
    if confirm "Create project templates?" "n"; then
        create_project_templates
    fi
}

# Main execution function
main() {
    echo "🔧 Configuring Sindri Development Environment"
    echo "=============================================="
    echo

    # Parse command line arguments
    local interactive=false
    local skip_claude_install=false
    local extensions_only=false
    local specific_extension=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --interactive)
                interactive=true
                shift
                ;;
            --skip-claude)
                skip_claude_install=true
                shift
                ;;
            --extensions-only)
                extensions_only=true
                shift
                ;;
            --extension)
                if [[ -z "$2" ]]; then
                    print_error "Extension name required for --extension option"
                    exit 1
                fi
                specific_extension="$2"
                shift 2
                ;;
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --interactive       Run interactive configuration prompts
  --skip-claude       Skip Claude Code/Flow installation
  --extensions-only   Only run extension scripts
  --extension <name>  Run a specific activated extension by name
  --help              Show this help message

This script configures the development environment inside the Fly.io VM.
Run this after connecting to your VM via SSH or IDE.

Extension System:
  Place custom installation scripts in $EXTENSIONS_DIR/
  Scripts are executed in alphabetical order during configuration.
  Use prefixes: pre-*, *, post-* to control execution phase.

  For --extension option:
  Extension must be activated first using:
    extension-manager.sh activate <extension-name>
EOF
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_status "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Check if running in the VM
    if ! is_in_vm; then
        print_error "This script should be run inside the Fly.io VM"
        print_error "Connect to your VM first: ssh developer@your-app.fly.dev -p 10022"
        exit 1
    fi

    # Handle specific extension mode
    if [[ -n "$specific_extension" ]]; then
        print_status "Running specific extension: $specific_extension"

        # Ensure workspace structure exists
        setup_workspace_structure

        # Source extension-manager to use its functions
        if [[ -f "$LIB_DIR/extension-manager.sh" ]]; then
            source "$LIB_DIR/extension-manager.sh"
        else
            print_error "Extension manager not found at $LIB_DIR/extension-manager.sh"
            exit 1
        fi

        # Check if extension is activated
        local extension_found=false
        local extension_activated=false
        local extension_file=""

        # Look for the extension
        for example_file in "$EXTENSIONS_DIR"/*.sh.example; do
            [[ ! -f "$example_file" ]] && continue

            local name=$(get_extension_name "$(basename "$example_file")")

            if [[ "$name" == "$specific_extension" ]]; then
                extension_found=true
                extension_file="${example_file%.example}"

                if [[ -f "$extension_file" ]]; then
                    extension_activated=true
                fi
                break
            fi
        done

        if [[ "$extension_found" == false ]]; then
            print_error "Extension '$specific_extension' not found"
            print_status "Available extensions:"
            for example_file in "$EXTENSIONS_DIR"/*.sh.example; do
                [[ -f "$example_file" ]] && echo "  - $(get_extension_name "$(basename "$example_file")")"
            done
            exit 1
        fi

        if [[ "$extension_activated" == false ]]; then
            print_warning "Extension '$specific_extension' is not activated"
            print_status "To activate it, run: extension-manager.sh activate $specific_extension"
            print_status "Or use the extension-manager alias in the VM: extension-manager activate $specific_extension"
            exit 1
        fi

        # Run the specific extension
        print_status "Executing extension: $(basename "$extension_file")"
        if bash "$extension_file"; then
            print_success "Extension '$specific_extension' completed successfully"
        else
            print_error "Extension '$specific_extension' failed with exit code $?"
            exit 1
        fi

        return 0
    fi

    # Handle extensions-only mode
    if [[ "$extensions_only" == true ]]; then
        print_status "Running extensions only..."

        # Ensure workspace structure exists
        setup_workspace_structure

        # Run extension phases
        run_extensions "pre-install"
        run_extensions "install"
        run_extensions "post-install"
        print_success "Extensions completed"
        return 0
    fi

    # Run configuration steps
    setup_workspace_structure

    # Setup MOTD banner
    if [[ -x "$SCRIPT_DIR/setup-motd.sh" ]]; then
        bash "$SCRIPT_DIR/setup-motd.sh"
    fi

    setup_nodejs

    # Setup GitHub CLI early if token is available (needed for agent-manager)
    if [[ -n "$GITHUB_TOKEN" ]]; then
        print_status "Setting up GitHub CLI authentication (needed for agent installation)..."
        configure_github_cli
        setup_gh_aliases
    else
        print_warning "No GITHUB_TOKEN found - agent installation may fail"
        print_status "To set: flyctl secrets set GITHUB_TOKEN=ghp_... -a <app-name>"
    fi

    # Run pre-install extensions
    run_extensions "pre-install"

    if [[ "$skip_claude_install" != true ]]; then
        install_claude_code
    fi

    # Run main install extensions
    run_extensions "install"

    setup_claude_config

    # Run post-install extensions
    run_extensions "post-install"

    if [[ "$interactive" == true ]]; then
        run_interactive_setup
    fi

    show_environment_status
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi