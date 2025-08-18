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

    # Get the directory containing this script (should be lib/)
    local lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Ensure lib directory exists in scripts directory for dependencies
    create_directory "$SCRIPTS_DIR/lib"

    # Copy library files to scripts/lib
    cp "$lib_dir/common.sh" "$SCRIPTS_DIR/lib/"
    cp "$lib_dir/git.sh" "$SCRIPTS_DIR/lib/"

    # Copy workspace utility scripts from lib directory
    local scripts=(backup restore new-project system-status)

    for script in "${scripts[@]}"; do
        if [ -f "$lib_dir/$script.sh" ]; then
            cp "$lib_dir/$script.sh" "$SCRIPTS_DIR/"
            chmod +x "$SCRIPTS_DIR/$script.sh"
            print_debug "Copied $script.sh to workspace scripts"
        else
            print_warning "Script $script.sh not found in $lib_dir"
        fi
    done

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