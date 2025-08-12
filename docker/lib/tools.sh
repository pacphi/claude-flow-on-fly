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

# Function to install additional development tools
install_dev_tools() {
    print_status "Installing additional development tools..."

    local npm_packages=(
        "typescript"
        "ts-node"
        "nodemon"
        "prettier"
        "eslint"
        "@typescript-eslint/parser"
        "@typescript-eslint/eslint-plugin"
    )

    local python_packages=(
        "black"
        "flake8"
        "autopep8"
        "requests"
        "ipython"
        "pytest"
        "mypy"
    )

    # Install npm packages if Node.js is available
    if command_exists npm; then
        print_status "Installing Node.js development packages..."
        for package in "${npm_packages[@]}"; do
            print_debug "Installing $package..."
            npm install -g "$package" 2>/dev/null || print_warning "Failed to install $package"
        done
    else
        print_warning "Skipping Node.js packages (npm not found)"
    fi

    # Install Python packages if pip3 is available
    if command_exists pip3; then
        print_status "Installing Python development packages..."
        for package in "${python_packages[@]}"; do
            print_debug "Installing $package..."
            pip3 install --user "$package" 2>/dev/null || print_warning "Failed to install $package"
        done
    else
        print_warning "Skipping Python packages (pip3 not found)"
    fi

    print_success "Additional development tools installed"
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
        "python3:Python"
        "pip3:pip"
        "git:Git"
        "claude:Claude Code"
        "docker:Docker"
        "go:Go"
        "rustc:Rust"
        "cargo:Cargo"
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
}

# Function to install language-specific tools
install_language_tools() {
    local language="$1"

    case "$language" in
        go|golang)
            install_go_tools
            ;;
        rust)
            install_rust_tools
            ;;
        python)
            install_python_tools
            ;;
        node|nodejs|javascript)
            install_nodejs_tools
            ;;
        *)
            print_error "Unknown language: $language"
            print_status "Supported languages: go, rust, python, node"
            return 1
            ;;
    esac
}

# Function to install Go tools
install_go_tools() {
    print_status "Installing Go development tools..."

    if ! command_exists go; then
        print_warning "Go is not installed. Installing Go..."

        # Download and install Go
        GO_VERSION="1.21.5"
        wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
        sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
        rm "go${GO_VERSION}.linux-amd64.tar.gz"

        # Add to PATH
        echo 'export PATH=$PATH:/usr/local/go/bin' >> "$HOME/.bashrc"
        export PATH=$PATH:/usr/local/go/bin
    fi

    # Install Go tools
    go install golang.org/x/tools/gopls@latest 2>/dev/null
    go install github.com/go-delve/delve/cmd/dlv@latest 2>/dev/null
    go install golang.org/x/lint/golint@latest 2>/dev/null

    print_success "Go development tools installed"
}

# Function to install Rust tools
install_rust_tools() {
    print_status "Installing Rust development tools..."

    if ! command_exists rustc; then
        print_warning "Rust is not installed. Installing Rust..."

        # Install Rust via rustup
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    # Install additional Rust tools
    cargo install cargo-watch 2>/dev/null || true
    cargo install cargo-edit 2>/dev/null || true
    cargo install cargo-audit 2>/dev/null || true

    print_success "Rust development tools installed"
}

# Function to install Python tools
install_python_tools() {
    print_status "Installing Python development tools..."

    if command_exists pip3; then
        pip3 install --user virtualenv pipenv poetry 2>/dev/null
        print_success "Python development tools installed"
    else
        print_error "pip3 not found"
        return 1
    fi
}

# Function to install Node.js tools
install_nodejs_tools() {
    print_status "Installing Node.js development tools..."

    if command_exists npm; then
        npm install -g yarn pnpm nx @angular/cli @vue/cli create-react-app 2>/dev/null
        print_success "Node.js development tools installed"
    else
        print_error "npm not found"
        return 1
    fi
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
export -f check_tool_versions install_language_tools install_go_tools
export -f install_rust_tools install_python_tools install_nodejs_tools run_extensions