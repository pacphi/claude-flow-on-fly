#!/bin/bash
# Create a new project with Claude configuration

# Source common utilities and git functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/git.sh"

# Parse command line arguments
PROJECT_NAME=""
PROJECT_TYPE="node"
GIT_NAME=""
GIT_EMAIL=""

# Function to show usage
show_usage() {
    echo "Usage: $0 <project_name> [options]"
    echo ""
    echo "Options:"
    echo "  --type <type>              Project type (node, python, go, rust, web) [default: node]"
    echo "  --git-name <name>          Git user name for this project"
    echo "  --git-email <email>        Git user email for this project"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 my-app"
    echo "  $0 my-app --type python"
    echo "  $0 my-app --git-name \"John Doe\" --git-email \"john@example.com\""
    exit 1
}

# Parse arguments
if [ $# -eq 0 ]; then
    show_usage
fi

PROJECT_NAME="$1"
shift

# Parse optional arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            PROJECT_TYPE="$2"
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

if [ -d "$PROJECT_DIR" ]; then
    print_error "Project $PROJECT_NAME already exists"
    exit 1
fi

print_status "Creating new $PROJECT_TYPE project: $PROJECT_NAME"

# Create project directory
create_directory "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize Git repository with proper configuration
init_git_repo "$PROJECT_DIR" "$PROJECT_TYPE"

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

# Create basic project structure based on type
case $PROJECT_TYPE in
    node)
        npm init -y
        # gitignore already created by init_git_repo
        ;;
    python)
        touch requirements.txt
        # gitignore already created by init_git_repo
        ;;
    go)
        go mod init "$PROJECT_NAME" 2>/dev/null || echo "module $PROJECT_NAME" > go.mod
        # gitignore already created by init_git_repo
        ;;
    rust)
        cargo init --name "$PROJECT_NAME" 2>/dev/null || {
            echo "[package]" > Cargo.toml
            echo "name = \"$PROJECT_NAME\"" >> Cargo.toml
            echo "version = \"0.1.0\"" >> Cargo.toml
            echo "edition = \"2021\"" >> Cargo.toml
            mkdir -p src
            echo "fn main() { println!(\"Hello, world!\"); }" > src/main.rs
        }
        # gitignore already created by init_git_repo
        ;;
    web)
        mkdir -p src css js
        touch src/index.html css/style.css js/app.js
        # gitignore already created by init_git_repo
        ;;
esac

# Create CLAUDE.md for project context
cat > CLAUDE.md << CLAUDE_EOF
# $PROJECT_NAME

## Project Overview
This is a $PROJECT_TYPE project for [brief description].

## Setup Instructions
[Add setup instructions here]

## Development Commands
[Add common commands here]

## Architecture Notes
[Add architectural decisions and patterns]

## Important Files
[List key files and their purposes]
CLAUDE_EOF

# Add and commit the new files
git add .
git commit -m "feat: initial project setup for $PROJECT_NAME"

# Initialize Claude Flow if available
if command_exists claude-flow || command_exists npx; then
    npx claude-flow@alpha init --force 2>/dev/null || true
fi

print_success "Project $PROJECT_NAME created successfully"
echo "📁 Location: $PROJECT_DIR"
echo "📝 Next steps:"
echo "   1. cd $PROJECT_DIR"
echo "   2. Edit CLAUDE.md with project details"
echo "   3. Start coding with: claude"

# Show Git configuration for this project
echo ""
echo "Git Configuration:"
echo "   User: $(git config user.name) <$(git config user.email)>"
echo "   Branch: $(git branch --show-current)"