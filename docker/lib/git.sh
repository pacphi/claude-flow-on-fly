#!/bin/bash
# git.sh - Git configuration and utilities
# This library provides functions for Git setup and configuration

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Function to configure Git
setup_git() {
    print_status "Configuring Git..."

    # Check if user has already configured Git
    if git config --global user.name >/dev/null 2>&1; then
        current_name=$(git config --global user.name)
        current_email=$(git config --global user.email)
        print_warning "Git already configured:"
        print_warning "  Name: $current_name"
        print_warning "  Email: $current_email"

        if ! confirm "Do you want to reconfigure Git?" "n"; then
            print_status "Keeping existing Git configuration"
            return 0
        fi
    fi

    # Prompt for Git configuration
    echo
    read -p "Enter your Git username: " git_name
    read -p "Enter your Git email: " git_email

    # Configure Git
    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.editor vim

    # Additional useful Git configurations
    git config --global color.ui auto
    git config --global core.autocrlf input
    git config --global fetch.prune true
    git config --global diff.colorMoved zebra
    git config --global rebase.autoStash true

    print_success "Git configured for $git_name <$git_email>"
}

# Function to setup Git aliases
setup_git_aliases() {
    print_status "Setting up useful Git aliases..."

    # Common aliases
    git config --global alias.co checkout
    git config --global alias.br branch
    git config --global alias.ci commit
    git config --global alias.st status
    git config --global alias.unstage 'reset HEAD --'
    git config --global alias.last 'log -1 HEAD'
    git config --global alias.visual '!gitk'

    # Logging aliases
    git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
    git config --global alias.ll "log --pretty=format:'%C(yellow)%h%Cred%d %Creset%s%Cblue [%cn]' --decorate --numstat"
    git config --global alias.ls "log --pretty=format:'%C(yellow)%h%Cred%d %Creset%s%Cblue [%cn]' --decorate"

    # Workflow aliases
    git config --global alias.ac '!git add -A && git commit'
    git config --global alias.pushup 'push -u origin HEAD'
    git config --global alias.cob 'checkout -b'
    git config --global alias.save '!git add -A && git commit -m "SAVEPOINT"'
    git config --global alias.wip '!git add -u && git commit -m "WIP"'
    git config --global alias.undo 'reset HEAD~1 --mixed'
    git config --global alias.amend 'commit -a --amend'

    # Maintenance aliases
    git config --global alias.bclean '!git branch --merged | grep -v "\*" | xargs -n 1 git branch -d'
    git config --global alias.bdone '!git checkout main && git branch --merged | grep -v "\*" | xargs -n 1 git branch -d'

    print_success "Git aliases configured"
}

# Function to setup Git hooks
setup_git_hooks() {
    local project_dir="${1:-$(pwd)}"

    if [[ ! -d "$project_dir/.git" ]]; then
        print_warning "Not a Git repository: $project_dir"
        return 1
    fi

    print_status "Setting up Git hooks in $project_dir..."

    local hooks_dir="$project_dir/.git/hooks"
    create_directory "$hooks_dir"

    # Pre-commit hook for code quality
    cat > "$hooks_dir/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook for code quality checks

# Source common utilities if available
if [ -f "/workspace/scripts/lib/common.sh" ]; then
    source "/workspace/scripts/lib/common.sh"
else
    print_status() { echo "[INFO] $1"; }
    print_error() { echo "[ERROR] $1"; }
fi

# Check for debugging code
if git diff --cached --name-only | xargs grep -E "console\.(log|debug|info|warn|error)" 2>/dev/null; then
    print_error "Debugging code detected. Please remove console statements."
    exit 1
fi

# Run prettier if available
if command -v prettier >/dev/null 2>&1; then
    files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(js|jsx|ts|tsx|json|css|scss|md)$')
    if [ -n "$files" ]; then
        echo "$files" | xargs prettier --write
        echo "$files" | xargs git add
    fi
fi

# Run eslint if available
if command -v eslint >/dev/null 2>&1; then
    files=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(js|jsx|ts|tsx)$')
    if [ -n "$files" ]; then
        echo "$files" | xargs eslint --fix
        echo "$files" | xargs git add
    fi
fi

exit 0
EOF
    chmod +x "$hooks_dir/pre-commit"

    # Commit message hook
    cat > "$hooks_dir/commit-msg" << 'EOF'
#!/bin/bash
# Commit message validation hook

commit_regex='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "Invalid commit message format!"
    echo "Format: <type>(<scope>): <subject>"
    echo "Example: feat(auth): add login functionality"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert"
    exit 1
fi
EOF
    chmod +x "$hooks_dir/commit-msg"

    print_success "Git hooks configured"
}

# Function to create gitignore file
create_gitignore() {
    local project_type="${1:-general}"
    local gitignore_file="${2:-.gitignore}"

    print_status "Creating .gitignore for $project_type project..."

    case "$project_type" in
        node|nodejs)
            cat > "$gitignore_file" << 'EOF'
# Dependencies
node_modules/
jspm_packages/

# Build outputs
dist/
build/
*.min.js
*.min.css

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Testing
coverage/
.nyc_output/

# Temporary
tmp/
temp/
EOF
            ;;
        python)
            cat > "$gitignore_file" << 'EOF'
# Byte-compiled / optimized
__pycache__/
*.py[cod]
*$py.class
*.so

# Virtual Environment
venv/
env/
ENV/
.venv

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Testing
.tox/
.coverage
.coverage.*
.cache
.pytest_cache/
htmlcov/

# Environment
.env
*.env

# IDE
.vscode/
.idea/
*.swp
*.swo

# Jupyter
.ipynb_checkpoints
EOF
            ;;
        go|golang)
            cat > "$gitignore_file" << 'EOF'
# Binaries
*.exe
*.exe~
*.dll
*.so
*.dylib

# Test binary
*.test

# Output
*.out

# Dependency directories
vendor/

# Go workspace
go.work

# Environment
.env
*.env

# IDE
.vscode/
.idea/
*.swp
EOF
            ;;
        rust)
            cat > "$gitignore_file" << 'EOF'
# Rust build
/target/
**/*.rs.bk
*.pdb

# Cargo
Cargo.lock

# IDE
.vscode/
.idea/
*.swp

# Environment
.env
EOF
            ;;
        *)
            cat > "$gitignore_file" << 'EOF'
# Build outputs
build/
dist/
out/
target/

# Dependencies
node_modules/
vendor/

# Environment
.env
.env.*
*.env

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Temporary
tmp/
temp/
.cache/
EOF
            ;;
    esac

    print_success ".gitignore created for $project_type project"
}

# Function to initialize Git repository
init_git_repo() {
    local project_dir="${1:-.}"
    local project_type="${2:-general}"

    cd "$project_dir" || return 1

    if [[ -d ".git" ]]; then
        print_warning "Git repository already initialized"
        return 0
    fi

    print_status "Initializing Git repository..."

    # Initialize repository
    git init

    # Create gitignore
    create_gitignore "$project_type"

    # Create initial commit
    git add .gitignore
    git commit -m "Initial commit"

    # Setup hooks
    setup_git_hooks "$project_dir"

    print_success "Git repository initialized"
}

# Function to clone and setup repository
clone_and_setup() {
    local repo_url="$1"
    local target_dir="${2:-}"

    if [[ -z "$repo_url" ]]; then
        print_error "Repository URL required"
        return 1
    fi

    print_status "Cloning repository: $repo_url"

    # Clone repository
    if [[ -n "$target_dir" ]]; then
        git clone "$repo_url" "$target_dir"
        cd "$target_dir" || return 1
    else
        git clone "$repo_url"
        repo_name=$(basename "$repo_url" .git)
        cd "$repo_name" || return 1
    fi

    # Setup hooks
    setup_git_hooks "$(pwd)"

    # Install dependencies if package files exist
    if [[ -f "package.json" ]] && command_exists npm; then
        print_status "Installing Node.js dependencies..."
        npm install
    fi

    if [[ -f "requirements.txt" ]] && command_exists pip3; then
        print_status "Installing Python dependencies..."
        pip3 install -r requirements.txt
    fi

    if [[ -f "go.mod" ]] && command_exists go; then
        print_status "Installing Go dependencies..."
        go mod download
    fi

    if [[ -f "Cargo.toml" ]] && command_exists cargo; then
        print_status "Installing Rust dependencies..."
        cargo build
    fi

    print_success "Repository cloned and configured"
}

# Export functions
export -f setup_git setup_git_aliases setup_git_hooks create_gitignore
export -f init_git_repo clone_and_setup