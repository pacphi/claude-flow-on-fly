#!/bin/bash
# workspace.sh - Workspace management functions
# This library provides functions for managing the workspace directory structure

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Function to setup workspace directory structure
setup_workspace_structure() {
    print_status "Setting up workspace directory structure..."

    # Create essential directories
    create_directory "$PROJECTS_DIR"
    create_directory "$SCRIPTS_DIR"
    create_directory "$BACKUPS_DIR"
    create_directory "$CONFIG_DIR"
    create_directory "$WORKSPACE_DIR/.cache"
    create_directory "$WORKSPACE_DIR/.local/bin"
    create_directory "$WORKSPACE_DIR/.local/share"

    # Create development-specific directories
    create_directory "$PROJECTS_DIR/active"
    create_directory "$PROJECTS_DIR/archive"
    create_directory "$PROJECTS_DIR/templates"

    # Create extensions directory for custom tools
    create_directory "$EXTENSIONS_DIR"

    print_success "Workspace structure created"
}

# Function to create workspace utility scripts
create_workspace_scripts() {
    print_status "Creating workspace utility scripts..."

    # Create backup script
    cat > "$SCRIPTS_DIR/backup.sh" << 'EOF'
#!/bin/bash
# Backup critical workspace data

# Source common utilities
source "$(dirname "$0")/lib/common.sh"

BACKUP_DATE=$(get_timestamp)
CRITICAL_DIRS="/workspace/projects /home/developer/.claude /workspace/.config"

print_status "Creating backup: backup_$BACKUP_DATE.tar.gz"

# Create backup directory
create_directory "$BACKUPS_DIR"

# Create tarball of critical directories
if tar -czf "$BACKUPS_DIR/backup_$BACKUP_DATE.tar.gz" $CRITICAL_DIRS 2>/dev/null; then
    print_success "Backup completed: backup_$BACKUP_DATE.tar.gz"
else
    print_warning "Some files may not be accessible, creating partial backup..."
    tar --ignore-failed-read -czf "$BACKUPS_DIR/backup_$BACKUP_DATE.tar.gz" $CRITICAL_DIRS
    print_success "Partial backup completed: backup_$BACKUP_DATE.tar.gz"
fi

# Keep only last 7 backups
find "$BACKUPS_DIR" -name "backup_*.tar.gz" -mtime +7 -delete

ls -lh "$BACKUPS_DIR/backup_$BACKUP_DATE.tar.gz"
EOF
    chmod +x "$SCRIPTS_DIR/backup.sh"

    # Create restore script
    cat > "$SCRIPTS_DIR/restore.sh" << 'EOF'
#!/bin/bash
# Restore from backup

# Source common utilities
source "$(dirname "$0")/lib/common.sh"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_filename>"
    echo "Available backups:"
    ls -1 "$BACKUPS_DIR"/backup_*.tar.gz 2>/dev/null || echo "  No backups found"
    exit 1
fi

BACKUP_FILE="$BACKUPS_DIR/$1"

if [ ! -f "$BACKUP_FILE" ]; then
    print_error "Backup file not found: $BACKUP_FILE"
    exit 1
fi

print_status "Restoring from: $1"

if confirm "This will overwrite existing files. Continue?"; then
    tar -xzf "$BACKUP_FILE" -C /
    print_success "Restore completed"
else
    print_warning "Restore cancelled"
fi
EOF
    chmod +x "$SCRIPTS_DIR/restore.sh"

    # Create new project script
    cat > "$SCRIPTS_DIR/new-project.sh" << 'EOF'
#!/bin/bash
# Create a new project with Claude configuration

# Source common utilities
source "$(dirname "$0")/lib/common.sh"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <project_name> [project_type]"
    echo "Project types: node, python, go, rust, web"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_TYPE="${2:-node}"
PROJECT_DIR="$PROJECTS_DIR/active/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    print_error "Project $PROJECT_NAME already exists"
    exit 1
fi

print_status "Creating new $PROJECT_TYPE project: $PROJECT_NAME"

# Create project directory
create_directory "$PROJECT_DIR"
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
        echo "venv/" >> .gitignore
        ;;
    go)
        go mod init "$PROJECT_NAME" 2>/dev/null || echo "module $PROJECT_NAME" > go.mod
        echo "bin/" > .gitignore
        echo "*.exe" >> .gitignore
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
        echo "target/" > .gitignore
        echo "Cargo.lock" >> .gitignore
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
if command_exists claude-flow || command_exists npx; then
    npx claude-flow@alpha init --force 2>/dev/null || true
fi

print_success "Project $PROJECT_NAME created successfully"
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

# Source common utilities
source "$(dirname "$0")/lib/common.sh"

echo "🖥️  System Status"
echo "=================="
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disk: $(df -h /workspace | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
echo

echo "🔧 Development Tools"
echo "===================="
echo "Node.js: $(node --version 2>/dev/null || echo 'Not installed')"
echo "npm: $(npm --version 2>/dev/null || echo 'Not installed')"
echo "Python: $(python3 --version 2>/dev/null || echo 'Not installed')"
echo "Git: $(git --version 2>/dev/null || echo 'Not installed')"
echo "Claude Code: $(claude --version 2>/dev/null || echo 'Not installed/authenticated')"
echo "Claude Flow: $(command -v claude-flow >/dev/null && echo 'Installed' || echo 'Available via npx')"
echo

echo "📁 Workspace"
echo "============"
echo "Projects: $(find /workspace/projects -mindepth 1 -maxdepth 2 -type d 2>/dev/null | wc -l) directories"
echo "Backups: $(ls /workspace/backups/*.tar.gz 2>/dev/null | wc -l) files"
echo "Extensions: $(ls /workspace/scripts/extensions.d/*.sh 2>/dev/null | wc -l) scripts"
echo "Storage:"
df -h /workspace | awk 'NR==2 {print "  Used: " $3 " / " $2 " (" $5 ")"}'
echo

echo "🌐 Network"
echo "=========="
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "SSH Status: $(pgrep sshd >/dev/null && echo 'Running' || echo 'Not running')"

# Check for custom extensions
if [ -d "$EXTENSIONS_DIR" ] && [ "$(ls -A $EXTENSIONS_DIR/*.sh 2>/dev/null)" ]; then
    echo
    echo "🔌 Custom Extensions"
    echo "===================="
    for ext in "$EXTENSIONS_DIR"/*.sh; do
        [ -f "$ext" ] && echo "  - $(basename "$ext")"
    done
fi
EOF
    chmod +x "$SCRIPTS_DIR/system-status.sh"

    print_success "Workspace utility scripts created"
}

# Function to create project templates
create_project_templates() {
    print_status "Creating project templates..."

    local templates_dir="$PROJECTS_DIR/templates"

    # Node.js template
    create_directory "$templates_dir/nodejs"
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
    create_directory "$templates_dir/python"
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

    # Go template
    create_directory "$templates_dir/go"
    cat > "$templates_dir/go/CLAUDE.md" << 'EOF'
# Go Project Template

## Project Overview
A Go application with modern development setup.

## Setup Instructions
```bash
go mod download
go build
```

## Development Commands
- `go run .` - Run application
- `go test ./...` - Run tests
- `go fmt ./...` - Format code
- `go vet ./...` - Lint code

## Architecture Notes
- Go modules for dependency management
- Standard library preferred
- Clean architecture principles

## Important Files
- `main.go` - Application entry point
- `go.mod` - Module definition
- `go.sum` - Dependency checksums
EOF

    # Rust template
    create_directory "$templates_dir/rust"
    cat > "$templates_dir/rust/CLAUDE.md" << 'EOF'
# Rust Project Template

## Project Overview
A Rust application with modern development setup.

## Setup Instructions
```bash
cargo build
cargo run
```

## Development Commands
- `cargo run` - Run application
- `cargo test` - Run tests
- `cargo fmt` - Format code
- `cargo clippy` - Lint code

## Architecture Notes
- Cargo for dependency management
- Error handling with Result types
- Memory safety by design

## Important Files
- `src/main.rs` - Application entry point
- `Cargo.toml` - Dependencies and metadata
- `tests/` - Test files
EOF

    print_success "Project templates created"
}

# Export functions
export -f setup_workspace_structure create_workspace_scripts create_project_templates