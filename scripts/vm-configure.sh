#!/bin/bash
# vm-configure.sh - Configuration script for Claude Development Environment
# This script runs ON the Fly.io VM to configure the development environment

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
WORKSPACE_DIR="/workspace"
SCRIPTS_DIR="$WORKSPACE_DIR/scripts"
PROJECTS_DIR="$WORKSPACE_DIR/projects"
BACKUPS_DIR="$WORKSPACE_DIR/backups"
CONFIG_DIR="$WORKSPACE_DIR/.config"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create workspace directory structure
setup_workspace_structure() {
    print_status "Setting up workspace directory structure..."

    # Create essential directories
    mkdir -p "$PROJECTS_DIR"
    mkdir -p "$SCRIPTS_DIR"
    mkdir -p "$BACKUPS_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$WORKSPACE_DIR/.cache"
    mkdir -p "$WORKSPACE_DIR/.local/bin"
    mkdir -p "$WORKSPACE_DIR/.local/share"

    # Create development-specific directories
    mkdir -p "$PROJECTS_DIR/active"
    mkdir -p "$PROJECTS_DIR/archive"
    mkdir -p "$PROJECTS_DIR/templates"

    print_success "Workspace structure created"
}

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

    # Install Claude Code globally
    npm install -g @anthropic-ai/claude-code

    # Verify installation
    if command_exists claude; then
        claude_version=$(claude --version 2>/dev/null || echo "Not authenticated")
        print_success "Claude Code installed: $claude_version"
    else
        print_error "Claude Code installation failed"
        return 1
    fi
}

# Note: Claude Flow is not installed globally - it's run via npx

# Function to install additional development tools
install_dev_tools() {
    print_status "Installing additional development tools..."

    # Install useful global npm packages
    npm install -g \
        typescript \
        ts-node \
        nodemon \
        prettier \
        eslint \
        @typescript-eslint/parser \
        @typescript-eslint/eslint-plugin

    # Install Python packages
    pip3 install --user \
        black \
        flake8 \
        autopep8 \
        requests \
        ipython

    print_success "Additional development tools installed"
}

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

        read -p "Do you want to reconfigure Git? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
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

    print_success "Git configured for $git_name <$git_email>"
}

# Function to create helpful scripts
create_workspace_scripts() {
    print_status "Creating workspace utility scripts..."

    # Create backup script
    cat > "$SCRIPTS_DIR/backup.sh" << 'EOF'
#!/bin/bash
# Backup critical workspace data

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/workspace/backups"
CRITICAL_DIRS="/workspace/projects /home/developer/.claude /workspace/.config"

echo "🔄 Creating backup: backup_$BACKUP_DATE.tar.gz"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create tarball of critical directories
tar -czf "$BACKUP_DIR/backup_$BACKUP_DATE.tar.gz" $CRITICAL_DIRS 2>/dev/null || {
    echo "⚠️  Some files may not be accessible, continuing..."
    tar --ignore-failed-read -czf "$BACKUP_DIR/backup_$BACKUP_DATE.tar.gz" $CRITICAL_DIRS
}

# Keep only last 7 backups
find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +7 -delete

echo "✅ Backup completed: backup_$BACKUP_DATE.tar.gz"
ls -lh "$BACKUP_DIR/backup_$BACKUP_DATE.tar.gz"
EOF
    chmod +x "$SCRIPTS_DIR/backup.sh"

    # Create restore script
    cat > "$SCRIPTS_DIR/restore.sh" << 'EOF'
#!/bin/bash
# Restore from backup

BACKUP_DIR="/workspace/backups"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_filename>"
    echo "Available backups:"
    ls -1 "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null || echo "  No backups found"
    exit 1
fi

BACKUP_FILE="$BACKUP_DIR/$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "🔄 Restoring from: $1"
read -p "This will overwrite existing files. Continue? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    tar -xzf "$BACKUP_FILE" -C /
    echo "✅ Restore completed"
else
    echo "❌ Restore cancelled"
fi
EOF
    chmod +x "$SCRIPTS_DIR/restore.sh"

    # Create project initialization script
    cat > "$SCRIPTS_DIR/new-project.sh" << 'EOF'
#!/bin/bash
# Create a new project with Claude configuration

if [ $# -eq 0 ]; then
    echo "Usage: $0 <project_name> [project_type]"
    echo "Project types: node, python, go, rust, web"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_TYPE="${2:-node}"
PROJECT_DIR="/workspace/projects/active/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    echo "❌ Project $PROJECT_NAME already exists"
    exit 1
fi

echo "🚀 Creating new $PROJECT_TYPE project: $PROJECT_NAME"

# Create project directory
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize Git
git init

# Create basic project structure based on type
case $PROJECT_TYPE in
    node)
        npm init -y
        echo "node_modules/" > .gitignore
        echo "*.log" >> .gitignore
        ;;
    python)
        touch requirements.txt
        echo "__pycache__/" > .gitignore
        echo "*.pyc" >> .gitignore
        echo ".env" >> .gitignore
        ;;
    web)
        mkdir -p src css js
        touch src/index.html css/style.css js/app.js
        echo "node_modules/" > .gitignore
        echo "dist/" >> .gitignore
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

# Initialize Claude Flow if available
if command -v claude-flow >/dev/null 2>&1; then
    npx claude-flow@alpha init --force
fi

echo "✅ Project $PROJECT_NAME created successfully"
echo "📁 Location: $PROJECT_DIR"
echo "📝 Next steps:"
echo "   1. cd $PROJECT_DIR"
echo "   2. Edit CLAUDE.md with project details"
echo "   3. Start coding with: claude"
EOF
    chmod +x "$SCRIPTS_DIR/new-project.sh"

    # Create system status script
    cat > "$SCRIPTS_DIR/system-status.sh" << 'EOF'
#!/bin/bash
# Show system and development environment status

echo "🖥️  System Status"
echo "=================="
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2 " (" $3/$2*100 "%)"}')"
echo "Disk: $(df -h /workspace | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo

echo "🔧 Development Tools"
echo "===================="
echo "Node.js: $(node --version 2>/dev/null || echo 'Not installed')"
echo "npm: $(npm --version 2>/dev/null || echo 'Not installed')"
echo "Python: $(python3 --version 2>/dev/null || echo 'Not installed')"
echo "Git: $(git --version 2>/dev/null || echo 'Not installed')"
echo "Claude Code: $(claude --version 2>/dev/null || echo 'Not installed/authenticated')"
echo "Claude Flow: $(command -v claude-flow >/dev/null && echo 'Installed' || echo 'Not installed')"
echo

echo "📁 Workspace"
echo "============"
echo "Projects: $(find /workspace/projects -mindepth 1 -maxdepth 2 -type d | wc -l) directories"
echo "Backups: $(ls /workspace/backups/*.tar.gz 2>/dev/null | wc -l) files"
echo "Storage:"
df -h /workspace | awk 'NR==2 {print "  Used: " $3 " / " $2 " (" $5 ")"}'
echo

echo "🌐 Network"
echo "=========="
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "SSH Status: $(pgrep sshd >/dev/null && echo 'Running' || echo 'Not running')"
EOF
    chmod +x "$SCRIPTS_DIR/system-status.sh"

    print_success "Workspace utility scripts created"
}

# Function to create project templates
create_project_templates() {
    print_status "Creating project templates..."

    local templates_dir="$PROJECTS_DIR/templates"

    # Node.js template
    mkdir -p "$templates_dir/nodejs"
    cat > "$templates_dir/nodejs/CLAUDE.md" << 'EOF'
# Node.js Project Template

## Project Overview
A Node.js application with modern development setup.

## Setup Instructions
```bash
npm install
npm run dev
```

## Development Commands
- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm test` - Run tests
- `npm run lint` - Lint code

## Architecture Notes
- ES6 modules
- Express.js for API endpoints
- Jest for testing

## Important Files
- `src/index.js` - Main application entry point
- `package.json` - Dependencies and scripts
- `tests/` - Test files
EOF

    # Python template
    mkdir -p "$templates_dir/python"
    cat > "$templates_dir/python/CLAUDE.md" << 'EOF'
# Python Project Template

## Project Overview
A Python application with modern development setup.

## Setup Instructions
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Development Commands
- `python main.py` - Run application
- `python -m pytest` - Run tests
- `black .` - Format code
- `flake8` - Lint code

## Architecture Notes
- Virtual environment for dependencies
- Black for code formatting
- Pytest for testing

## Important Files
- `main.py` - Application entry point
- `requirements.txt` - Dependencies
- `tests/` - Test files
EOF

    print_success "Project templates created"
}

# Function to configure Claude Code defaults
setup_claude_config() {
    print_status "Setting up Claude Code configuration..."

    # Create Claude configuration directory
    mkdir -p ~/.claude

    # Create global CLAUDE.md with user preferences
    cat > ~/.claude/CLAUDE.md << 'EOF'
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
    mkdir -p ~/.claude
    cat > ~/.claude/settings.json << 'EOF'
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

# Function to show environment status
show_environment_status() {
    echo
    print_success "🎉 Environment Configuration Complete!"
    echo
    print_status "📋 Environment Summary:"
    echo "  • Workspace: $WORKSPACE_DIR"
    echo "  • Node.js: $(node --version)"
    echo "  • npm: $(npm --version)"
    echo "  • Claude Code: $(command_exists claude && echo "Installed" || echo "Installation failed")"
    echo "  • Claude Flow: $(command_exists claude-flow && echo "Installed" || echo "Installation failed")"
    echo "  • Git: $(git config --global user.name) <$(git config --global user.email)>"
    echo
    print_status "🔧 Available Scripts:"
    echo "  • $SCRIPTS_DIR/backup.sh - Backup workspace data"
    echo "  • $SCRIPTS_DIR/restore.sh - Restore from backup"
    echo "  • $SCRIPTS_DIR/new-project.sh - Create new project"
    echo "  • $SCRIPTS_DIR/system-status.sh - Show system status"
    echo
    print_status "📁 Project Structure:"
    echo "  • $PROJECTS_DIR/active/ - Active projects"
    echo "  • $PROJECTS_DIR/archive/ - Archived projects"
    echo "  • $PROJECTS_DIR/templates/ - Project templates"
    echo
    print_status "🚀 Next Steps:"
    echo "  1. Authenticate Claude: claude"
    echo "  2. Create a project: $SCRIPTS_DIR/new-project.sh my-app node"
    echo "  3. Start coding with AI assistance!"
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
    read -p "Install additional development tools? (eslint, prettier, etc.) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_dev_tools
    fi

    echo
    read -p "Create project templates? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_project_templates
    fi
}

# Main execution function
main() {
    echo "🔧 Configuring Claude Development Environment"
    echo "============================================"
    echo

    # Parse command line arguments
    local interactive=false
    local skip_claude_install=false

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
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --interactive       Run interactive configuration prompts
  --skip-claude       Skip Claude Code/Flow installation
  --help              Show this help message

This script configures the development environment inside the Fly.io VM.
Run this after connecting to your VM via SSH or IDE.

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
    if [[ ! -d "/workspace" ]]; then
        print_error "This script should be run inside the Fly.io VM"
        print_error "Connect to your VM first: ssh developer@your-app.fly.dev -p 10022"
        exit 1
    fi

    # Run configuration steps
    setup_workspace_structure
    setup_nodejs

    if [[ "$skip_claude_install" != true ]]; then
        install_claude_code
    fi

    create_workspace_scripts
    setup_claude_config

    if [[ "$interactive" == true ]]; then
        run_interactive_setup
    fi

    show_environment_status
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi