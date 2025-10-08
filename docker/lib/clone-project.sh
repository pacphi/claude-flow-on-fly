#!/bin/bash
# Clone or fork an existing project with Claude enhancements

# Source common utilities and git functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/git.sh"

# Parse command line arguments
REPO_URL=""
FORK_MODE=false
BRANCH_NAME=""
CLONE_DEPTH=""
GIT_NAME=""
GIT_EMAIL=""
FEATURE_BRANCH=""
SKIP_DEPS=false
SKIP_ENHANCE=false
PROJECT_NAME=""

# Function to show usage
show_usage() {
    echo "Usage: $0 <repository-url> [options]"
    echo ""
    echo "Clone or fork a repository and enhance it with Claude tools"
    echo ""
    echo "Options:"
    echo "  --fork              Fork repo before cloning (requires gh CLI)"
    echo "  --branch <name>     Checkout specific branch after clone"
    echo "  --depth <n>         Shallow clone with n commits"
    echo "  --git-name <name>   Configure Git user name for this project"
    echo "  --git-email <email> Configure Git user email for this project"
    echo "  --feature <name>    Create and checkout feature branch after clone"
    echo "  --no-deps           Skip dependency installation"
    echo "  --no-enhance        Skip all enhancements (just clone/fork)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/user/my-app"
    echo "  $0 https://github.com/original/project --fork"
    echo "  $0 https://github.com/original/project --fork --feature add-new-feature"
    echo "  $0 https://github.com/company/app --git-name \"John Doe\" --git-email \"john@company.com\""
    exit 1
}

# Parse arguments
if [ $# -eq 0 ]; then
    show_usage
fi

# Check for help flag first
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
fi

REPO_URL="$1"
shift

# Validate repository URL
if [[ ! "$REPO_URL" =~ ^(https?://|git@) ]]; then
    print_error "Invalid repository URL: $REPO_URL"
    exit 1
fi

# Extract project name from URL
PROJECT_NAME=$(basename "$REPO_URL" .git)
if [[ -z "$PROJECT_NAME" ]]; then
    print_error "Could not determine project name from URL"
    exit 1
fi

# Parse optional arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fork)
            FORK_MODE=true
            shift
            ;;
        --branch)
            BRANCH_NAME="$2"
            shift 2
            ;;
        --depth)
            CLONE_DEPTH="$2"
            shift 2
            ;;
        --git-name)
            GIT_NAME="$2"
            shift 2
            ;;
        --git-email)
            GIT_EMAIL="$2"
            shift 2
            ;;
        --feature)
            FEATURE_BRANCH="$2"
            shift 2
            ;;
        --no-deps)
            SKIP_DEPS=true
            shift
            ;;
        --no-enhance)
            SKIP_ENHANCE=true
            shift
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            ;;
    esac
done

PROJECT_DIR="$PROJECTS_DIR/active/$PROJECT_NAME"

# Check if project already exists
if [ -d "$PROJECT_DIR" ]; then
    print_error "Project $PROJECT_NAME already exists at $PROJECT_DIR"
    exit 1
fi

# Fork mode handling
if [[ "$FORK_MODE" == true ]]; then
    # Check for gh CLI
    if ! command_exists gh; then
        print_error "GitHub CLI (gh) is required for forking. Please install it first."
        exit 1
    fi

    # Check gh authentication
    if ! gh auth status >/dev/null 2>&1; then
        print_error "GitHub CLI is not authenticated. Please run: gh auth login"
        exit 1
    fi

    print_status "Forking repository: $REPO_URL"

    # Fork and clone in one command
    cd "$PROJECTS_DIR/active" || exit 1
    if ! gh repo fork "$REPO_URL" --clone; then
        print_error "Failed to fork repository"
        exit 1
    fi

    cd "$PROJECT_NAME" || exit 1

    # Setup fork-specific configurations
    if [[ "$SKIP_ENHANCE" != true ]]; then
        print_status "Setting up fork remotes and aliases..."
        setup_fork_remotes
        setup_fork_aliases
    fi
else
    # Regular clone mode
    print_status "Cloning repository: $REPO_URL"

    # Build clone command
    CLONE_CMD="git clone"
    if [[ -n "$CLONE_DEPTH" ]]; then
        CLONE_CMD="$CLONE_CMD --depth $CLONE_DEPTH"
    fi
    if [[ -n "$BRANCH_NAME" ]]; then
        CLONE_CMD="$CLONE_CMD --branch $BRANCH_NAME"
    fi
    CLONE_CMD="$CLONE_CMD \"$REPO_URL\" \"$PROJECT_DIR\""

    # Execute clone
    eval $CLONE_CMD
    if [ $? -ne 0 ]; then
        print_error "Failed to clone repository"
        exit 1
    fi

    cd "$PROJECT_DIR" || exit 1
fi

# Checkout specific branch if requested (and not already done during clone)
if [[ -n "$BRANCH_NAME" ]] && [[ "$FORK_MODE" == true ]]; then
    print_status "Checking out branch: $BRANCH_NAME"
    git checkout "$BRANCH_NAME" 2>/dev/null || {
        print_warning "Branch $BRANCH_NAME not found locally, trying to fetch from upstream"
        git fetch upstream "$BRANCH_NAME" 2>/dev/null && git checkout -b "$BRANCH_NAME" "upstream/$BRANCH_NAME"
    } || {
        print_error "Could not checkout branch: $BRANCH_NAME"
    }
fi

# Configure Git user for this project if provided
if [[ -n "$GIT_NAME" ]] || [[ -n "$GIT_EMAIL" ]]; then
    print_status "Configuring Git for this project..."
    if [[ -n "$GIT_NAME" ]]; then
        git config user.name "$GIT_NAME"
        print_success "Git user name set to: $GIT_NAME"
    fi
    if [[ -n "$GIT_EMAIL" ]]; then
        git config user.email "$GIT_EMAIL"
        print_success "Git user email set to: $GIT_EMAIL"
    fi
fi

# Apply enhancements unless skipped
if [[ "$SKIP_ENHANCE" != true ]]; then
    print_status "Applying Claude enhancements..."

    # Setup Git hooks
    setup_git_hooks "$PROJECT_DIR"

    # Install dependencies unless skipped
    if [[ "$SKIP_DEPS" != true ]]; then
        print_status "Installing project dependencies..."

        # Use existing dependency installation logic from git.sh
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
    fi

    # Check for CLAUDE.md and create if missing
    if [[ ! -f "CLAUDE.md" ]]; then
        print_status "No CLAUDE.md found. Running claude /init to create one..."
        if command_exists claude; then
            claude /init
        else
            print_warning "Claude CLI not found. Creating basic CLAUDE.md template..."
            cat > CLAUDE.md << CLAUDE_EOF
# $PROJECT_NAME

## Project Overview
This project was cloned from: $REPO_URL

## Setup Instructions
[Add setup instructions here]

## Development Commands
[Add common commands here]

## Architecture Notes
[Add architectural decisions and patterns]

## Important Files
[List key files and their purposes]
CLAUDE_EOF
            print_success "Basic CLAUDE.md template created. Please update with project details."
        fi
    else
        print_success "CLAUDE.md already exists"
    fi

    # Initialize Claude Flow if available
    if command_exists claude-flow || command_exists npx; then
        print_status "Initializing Claude Flow..."
        npx claude-flow@alpha init --force 2>/dev/null || true
    fi

    # Initialize agent-flow if available
    if command_exists npx; then
        print_status "Initializing agent-flow..."
        npx --yes agentic-flow --help >/dev/null 2>&1 || true
    fi
fi

# Create feature branch if requested
if [[ -n "$FEATURE_BRANCH" ]]; then
    print_status "Creating feature branch: $FEATURE_BRANCH"
    git checkout -b "$FEATURE_BRANCH"
    print_success "Switched to new branch: $FEATURE_BRANCH"
fi

# Final success message
print_success "Project $PROJECT_NAME cloned successfully"
echo "📁 Location: $PROJECT_DIR"
echo "📝 Next steps:"
echo "   1. cd $PROJECT_DIR"
if [[ ! -f "CLAUDE.md" ]] || [[ "$SKIP_ENHANCE" == true ]]; then
    echo "   2. Run 'claude /init' to set up project context"
fi
echo "   3. Start coding with: claude"

# Show Git configuration for this project
echo ""
echo "Git Configuration:"
echo "   User: $(git config user.name) <$(git config user.email)>"
echo "   Branch: $(git branch --show-current)"
if [[ "$FORK_MODE" == true ]]; then
    echo "   Origin: $(git remote get-url origin 2>/dev/null || echo 'not set')"
    echo "   Upstream: $(git remote get-url upstream 2>/dev/null || echo 'not set')"
fi