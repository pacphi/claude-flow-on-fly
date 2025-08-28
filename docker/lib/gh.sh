#!/bin/bash
# gh.sh - GitHub CLI installation and configuration
# This library provides functions for GitHub CLI setup

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Function to install GitHub CLI
install_github_cli() {
    print_status "Checking GitHub CLI installation..."

    if command_exists gh; then
        local current_version=$(gh --version | head -n1)
        print_success "GitHub CLI already installed: $current_version"
        return 0
    fi

    print_status "Installing GitHub CLI..."

    # Install GitHub CLI based on the system
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu installation
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh -y
    elif [[ -f /etc/redhat-release ]]; then
        # RHEL/Fedora installation
        sudo dnf install 'dnf-command(config-manager)'
        sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        sudo dnf install gh -y
    elif command_exists brew; then
        # macOS/Homebrew installation
        brew install gh
    else
        print_error "Unsupported system for automatic GitHub CLI installation"
        print_status "Please install manually from: https://github.com/cli/cli#installation"
        return 1
    fi

    if command_exists gh; then
        local version=$(gh --version | head -n1)
        print_success "GitHub CLI installed: $version"
    else
        print_error "GitHub CLI installation failed"
        return 1
    fi
}

# Function to configure GitHub CLI with token
configure_github_cli() {
    print_status "Configuring GitHub CLI..."

    if [[ -z "$GITHUB_TOKEN" ]]; then
        print_warning "No GITHUB_TOKEN found in environment"
        print_status "GitHub CLI will need manual authentication"
        print_status "Run: gh auth login"
        return 1
    fi

    # Check if already authenticated
    if gh auth status >/dev/null 2>&1; then
        print_success "GitHub CLI already authenticated"
        gh auth status
        return 0
    fi

    print_status "Authenticating GitHub CLI with token..."

    # Create config directory if it doesn't exist
    mkdir -p "$HOME/.config/gh"

    # Configure GitHub CLI with token
    echo "$GITHUB_TOKEN" | gh auth login --with-token

    if gh auth status >/dev/null 2>&1; then
        print_success "GitHub CLI authenticated successfully"
        gh auth status
    else
        print_error "GitHub CLI authentication failed"
        return 1
    fi
}

# Function to setup GitHub CLI aliases
setup_gh_aliases() {
    print_status "Setting up GitHub CLI aliases..."

    # Create useful gh aliases
    gh alias set --shell prs 'gh pr list --author="@me"' 2>/dev/null || true
    gh alias set --shell issues 'gh issue list --assignee="@me"' 2>/dev/null || true
    gh alias set --shell clone 'gh repo clone "$@"' 2>/dev/null || true
    gh alias set --shell fork 'gh repo fork --clone' 2>/dev/null || true
    gh alias set --shell web 'gh repo view --web' 2>/dev/null || true
    gh alias set --shell pr-checkout 'gh pr checkout' 2>/dev/null || true
    gh alias set --shell pr-create 'gh pr create --fill' 2>/dev/null || true

    print_success "GitHub CLI aliases configured"
}

# Function to check GitHub CLI status
check_gh_status() {
    print_status "Checking GitHub CLI status..."

    if ! command_exists gh; then
        print_error "GitHub CLI not installed"
        return 1
    fi

    local version=$(gh --version | head -n1)
    print_success "GitHub CLI version: $version"

    if gh auth status >/dev/null 2>&1; then
        print_success "Authentication status:"
        gh auth status
    else
        print_warning "Not authenticated"
        print_status "Run: gh auth login"
    fi

    # Show configured aliases if any
    local aliases=$(gh alias list 2>/dev/null)
    if [[ -n "$aliases" ]]; then
        print_status "Configured aliases:"
        echo "$aliases"
    fi
}

# Function to setup GitHub workflow helpers
setup_gh_workflows() {
    print_status "Setting up GitHub workflow helpers..."

    # Create workflow management script
    cat > "$HOME/.gh-workflow-helper.sh" << 'EOF'
#!/bin/bash
# GitHub workflow helper functions

# Function to create a new feature branch and PR
gh_feature() {
    local branch_name="$1"
    local pr_title="$2"

    if [[ -z "$branch_name" ]]; then
        echo "Usage: gh_feature <branch-name> [pr-title]"
        return 1
    fi

    # Create and checkout new branch
    git checkout -b "$branch_name"

    # Make initial commit if there are changes
    if [[ -n $(git status --porcelain) ]]; then
        git add -A
        git commit -m "feat: initial commit for $branch_name"
    fi

    # Push branch
    git push -u origin "$branch_name"

    # Create PR if title provided
    if [[ -n "$pr_title" ]]; then
        gh pr create --title "$pr_title" --body "Feature branch: $branch_name" --draft
    fi
}

# Function to sync fork with upstream
gh_sync_fork() {
    local upstream="${1:-upstream}"
    local branch="${2:-main}"

    # Add upstream if not exists
    if ! git remote | grep -q "$upstream"; then
        local upstream_url=$(gh repo view --json parent --jq '.parent.url' 2>/dev/null)
        if [[ -n "$upstream_url" ]]; then
            git remote add "$upstream" "$upstream_url"
        else
            echo "Not a fork or upstream not detected"
            return 1
        fi
    fi

    # Fetch and merge upstream
    git fetch "$upstream"
    git checkout "$branch"
    git merge "$upstream/$branch"
    git push origin "$branch"
}

# Export functions for use in shell
export -f gh_feature gh_sync_fork
EOF

    chmod +x "$HOME/.gh-workflow-helper.sh"

    # Source in bashrc if not already
    if ! grep -q ".gh-workflow-helper.sh" "$HOME/.bashrc" 2>/dev/null; then
        echo "source $HOME/.gh-workflow-helper.sh" >> "$HOME/.bashrc"
    fi

    print_success "GitHub workflow helpers configured"
    print_status "Available commands: gh_feature, gh_sync_fork"
}

# Main setup function
setup_github_cli() {
    print_status "Setting up GitHub CLI environment..."

    # Install if needed
    if ! command_exists gh; then
        install_github_cli || return 1
    fi

    # Configure authentication
    configure_github_cli

    # Setup aliases
    setup_gh_aliases

    # Setup workflow helpers
    setup_gh_workflows

    print_success "GitHub CLI setup complete"
}

# Export functions
export -f install_github_cli configure_github_cli setup_gh_aliases
export -f check_gh_status setup_gh_workflows setup_github_cli