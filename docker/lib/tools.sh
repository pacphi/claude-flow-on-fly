#!/bin/bash
# tools.sh - Tool installation and configuration functions
# This library provides functions for installing development tools

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Function to install NVM (Node Version Manager)
install_nvm() {
    print_status "Installing Node Version Manager (NVM)..."

    local nvm_version="v0.40.3"

    if [ -d "$HOME/.nvm" ]; then
        print_warning "NVM already installed at $HOME/.nvm"
        return 0
    fi

    # Install NVM
    if curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh" | bash; then
        print_success "NVM ${nvm_version} installed successfully"

        # Load NVM for immediate use
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

        return 0
    else
        print_error "Failed to install NVM"
        return 1
    fi
}

# Function to install Node.js and npm
setup_nodejs() {
    print_status "Setting up Node.js environment..."

    # Load NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if ! command_exists nvm; then
        print_status "NVM not found, installing it first..."
        if ! install_nvm; then
            print_error "Failed to install NVM"
            return 1
        fi

        # Reload NVM after installation
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi

    # Install latest LTS Node.js
    nvm install --lts
    nvm use --lts
    nvm alias default lts/*

    # Update npm to latest
    npm install -g npm@latest

    # Verify installation
    node_version=$(node --version)
    npm_version=$(npm --version)

    print_success "Node.js $node_version and npm $npm_version installed"
}

# Function to install Claude Code
install_claude_code() {
    print_status "Installing Claude Code..."

    # Check if Node.js is available
    if ! command_exists npm; then
        print_error "npm not found. Please install Node.js first."
        return 1
    fi

    # Install Claude Code globally
    if npm install -g @anthropic-ai/claude-code; then
        # Verify installation
        if command_exists claude; then
            claude_version=$(claude --version 2>/dev/null || echo "Not authenticated")
            print_success "Claude Code installed: $claude_version"
        else
            print_warning "Claude Code installed but command not found in PATH"
            print_status "You may need to reload your shell or add npm global bin to PATH"
        fi
    else
        print_error "Claude Code installation failed"
        return 1
    fi
}

# Function to install additional Node.js development tools
install_dev_tools() {
    print_status "Installing additional Node.js development tools..."

    local npm_packages=(
        "typescript"
        "ts-node"
        "nodemon"
        "prettier"
        "eslint"
        "@typescript-eslint/parser"
        "@typescript-eslint/eslint-plugin"
        "goalie"
    )

    # Install npm packages if Node.js is available
    if command_exists npm; then
        print_status "Installing Node.js development packages..."
        for package in "${npm_packages[@]}"; do
            print_debug "Installing $package..."
            npm install -g "$package" 2>/dev/null || print_warning "Failed to install $package"
        done
        print_success "Node.js development tools installed"
    else
        print_warning "npm not found - Node.js setup required first"
        return 1
    fi
}

# Function to configure Claude Code defaults
setup_claude_config() {
    print_status "Setting up Claude Code configuration..."

    # Create Claude configuration directory
    create_directory "$HOME/.claude"

    # Create global CLAUDE.md with user preferences
    cat > "$HOME/.claude/CLAUDE.md" << 'EOF'
# Global Claude Preferences

## Code Style
- Use 2 spaces for indentation
- Use semicolons in JavaScript/TypeScript
- Prefer const over let
- Use meaningful variable names

## Git Workflow
- Use conventional commits (feat:, fix:, docs:, etc.)
- Create feature branches for new work
- Write descriptive commit messages

## Development Practices
- Write tests for new features
- Add documentation for public APIs
- Use TypeScript for new JavaScript projects
- Follow project-specific style guides

## Preferred Libraries
- React for frontend applications
- Express.js for Node.js APIs
- Jest for JavaScript testing
- Pytest for Python testing
EOF

    # Create settings.json with useful hooks
    cat > "$HOME/.claude/settings.json" << 'EOF'
{
  "hooks": [
    {
      "matcher": "Edit|Write",
      "type": "command",
      "command": "prettier --write \"$CLAUDE_FILE_PATHS\" 2>/dev/null || echo 'Prettier not available for this file type'"
    },
    {
      "matcher": "Edit",
      "type": "command",
      "command": "if [[ \"$CLAUDE_FILE_PATHS\" =~ \\.(ts|tsx)$ ]]; then npx tsc --noEmit --skipLibCheck \"$CLAUDE_FILE_PATHS\" 2>/dev/null || echo '⚠️ TypeScript errors detected - please review'; fi"
    }
  ]
}
EOF

    print_success "Claude Code configuration created"
}

# Function to check tool versions
check_tool_versions() {
    print_status "Checking installed tool versions..."

    local tools=(
        "node:Node.js"
        "npm:npm"
        "git:Git"
        "claude:Claude Code"
    )

    for tool_spec in "${tools[@]}"; do
        IFS=':' read -r cmd name <<< "$tool_spec"
        if command_exists "$cmd"; then
            version=$($cmd --version 2>/dev/null | head -n1)
            echo "✓ $name: $version"
        else
            echo "✗ $name: Not installed"
        fi
    done

    # Check for optional tools installed via extensions
    print_status "Checking optional tools (from extensions)..."
    local optional_tools=(
        "python3:Python"
        "pip3:pip"
        "docker:Docker"
        "go:Go"
        "rustc:Rust"
        "cargo:Cargo"
    )

    for tool_spec in "${optional_tools[@]}"; do
        IFS=':' read -r cmd name <<< "$tool_spec"
        if command_exists "$cmd"; then
            version=$($cmd --version 2>/dev/null | head -n1)
            echo "✓ $name: $version (via extension)"
        fi
    done
}

# Function to run custom extensions
run_extensions() {
    local phase="${1:-install}"

    if [[ ! -d "$EXTENSIONS_DIR" ]]; then
        print_debug "Extensions directory not found: $EXTENSIONS_DIR"
        return 0
    fi

    local extension_files=("$EXTENSIONS_DIR"/*.sh)

    if [[ ! -e "${extension_files[0]}" ]]; then
        print_debug "No extension scripts found in $EXTENSIONS_DIR"
        return 0
    fi

    print_status "Running extension scripts (phase: $phase)..."

    # Debug: Show discovered extensions and process them in single loop
    print_debug "Discovered extensions in $EXTENSIONS_DIR:"
    local total_count=0
    local executed_count=0

    # Single loop: discovery, debug output, and execution
    for extension in "${extension_files[@]}"; do
        if [[ -f "$extension" ]] && [[ -x "$extension" ]]; then
            local basename=$(basename "$extension")
            local assigned_phase=""
            local will_execute=false

            total_count=$((total_count + 1))

            # Determine which phase this extension belongs to
            if [[ "$basename" =~ ^pre- ]]; then
                assigned_phase="pre-install"
                if [[ "$phase" == "pre-install" ]]; then
                    will_execute=true
                fi
            elif [[ "$basename" =~ ^post- ]]; then
                assigned_phase="post-install"
                if [[ "$phase" == "post-install" ]]; then
                    will_execute=true
                fi
            else
                assigned_phase="install"
                if [[ "$phase" == "install" ]]; then
                    will_execute=true
                fi
            fi

            print_debug "  $basename → $assigned_phase phase (will run: $will_execute)"

            # Execute if matches current phase
            if [[ "$will_execute" == true ]]; then
                case "$assigned_phase" in
                    "pre-install")
                        print_status "Running pre-install extension: $basename"
                        ;;
                    "post-install")
                        print_status "Running post-install extension: $basename"
                        ;;
                    *)
                        print_status "Running extension: $basename"
                        ;;
                esac

                if bash "$extension"; then
                    executed_count=$((executed_count + 1))
                else
                    print_warning "Extension failed: $basename"
                fi
            fi
        fi
    done

    print_debug "Phase summary: $executed_count of $total_count extensions executed in '$phase' phase"

    # Log phase execution status
    if [[ $executed_count -eq 0 ]]; then
        print_status "No extensions found for $phase phase, skipping"
    else
        print_status "Found $executed_count extensions for $phase phase"
    fi

    print_success "Extension scripts completed for $phase phase ($executed_count executed)"
}

# Export functions
export -f install_nvm setup_nodejs install_claude_code install_dev_tools setup_claude_config
export -f check_tool_versions run_extensions
