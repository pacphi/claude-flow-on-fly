#!/bin/bash
# tools.sh - Tool installation and configuration functions
# This library provides functions for installing development tools

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Function to install Node.js and npm
setup_nodejs() {
    print_status "Setting up Node.js environment..."

    # Load NVM
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    if ! command_exists nvm; then
        print_error "NVM not found. Please check Docker installation."
        return 1
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

# Function to install language-specific tools via extensions
install_language_tools() {
    local language="$1"

    print_status "Language-specific tools should be installed via extensions"
    print_status "Available extension examples in $EXTENSIONS_DIR:"
    print_status "  - 05-python.sh.example - Python toolchain"
    print_status "  - 10-rust.sh.example - Rust toolchain"
    print_status "  - 20-golang.sh.example - Go toolchain"
    print_status "  - 30-docker.sh.example - Docker tools"
    print_status "  - 40-jvm.sh.example - Java/JVM tools"
    print_status "..."
    print_status ""
    print_status "To enable an extension:"
    print_status "  1. Rename the .example file (e.g., mv 10-rust.sh.example 10-rust.sh)"
    print_status "  2. Run: $0 --extensions-only"

    return 0
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
        print_debug "No extension scripts found"
        return 0
    fi

    print_status "Running extension scripts (phase: $phase)..."

    for extension in "${extension_files[@]}"; do
        if [[ -f "$extension" ]] && [[ -x "$extension" ]]; then
            local basename=$(basename "$extension")

            # Check if extension should run in this phase
            if [[ "$phase" == "pre-install" ]] && [[ "$basename" =~ ^pre- ]]; then
                print_status "Running pre-install extension: $basename"
                source "$extension" || print_warning "Extension failed: $basename"
            elif [[ "$phase" == "install" ]] && [[ ! "$basename" =~ ^(pre-|post-) ]]; then
                print_status "Running extension: $basename"
                source "$extension" || print_warning "Extension failed: $basename"
            elif [[ "$phase" == "post-install" ]] && [[ "$basename" =~ ^post- ]]; then
                print_status "Running post-install extension: $basename"
                source "$extension" || print_warning "Extension failed: $basename"
            fi
        fi
    done

    print_success "Extension scripts completed"
}

# Export functions
export -f setup_nodejs install_claude_code install_dev_tools setup_claude_config
export -f check_tool_versions install_language_tools run_extensions