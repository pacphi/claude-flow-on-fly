#!/bin/bash
# Create a new project with Claude configuration and intelligent type detection

# Source common utilities and git functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
source "${SCRIPT_DIR}/git.sh"

# Configuration
TEMPLATES_CONFIG="${SCRIPT_DIR}/project-templates.yaml"
PROJECT_NAME=""
PROJECT_TYPE=""
AUTO_DETECT=true
GIT_NAME=""
GIT_EMAIL=""
INTERACTIVE=false
LIST_TYPES=false

# YAML parsing helper (simple key extraction)
get_yaml_value() {
    local file="$1"
    local key="$2"
    if [[ -f "$file" ]]; then
        grep -E "^\s*${key}:" "$file" | sed 's/.*: *//' | sed 's/^["\x27]//' | sed 's/["\x27]$//'
    fi
}

# Get available project types from templates
get_available_types() {
    if [[ -f "$TEMPLATES_CONFIG" ]]; then
        awk '
        /^templates:/ { in_templates=1; next }
        /^detection_rules:/ { in_templates=0 }
        in_templates && /^  [a-zA-Z][a-zA-Z0-9_-]*:$/ {
            gsub(/:$/, "", $1); gsub(/^  /, "", $1); print $1
        }
        ' "$TEMPLATES_CONFIG"
    else
        echo "node python go rust rails django spring dotnet terraform docker"
    fi
}

# Detect project type from name patterns
detect_project_type() {
    local project_name="$1"
    local name_lower
    name_lower=$(echo "$project_name" | tr '[:upper:]' '[:lower:]')

    # Simple pattern matching for common cases
    case "$name_lower" in
        *rails*) echo "rails" ;;
        *django*) echo "django" ;;
        *spring*) echo "spring" ;;
        *terraform*) echo "terraform" ;;
        *tf*) echo "terraform" ;;
        *infra*) echo "terraform" ;;
        *infrastructure*) echo "terraform" ;;
        *docker*) echo "docker" ;;
        *container*) echo "docker" ;;
        *api*) echo "api" ;;
        *service*) echo "api" ;;
        *microservice*) echo "api" ;;
        *web*) echo "web" ;;
        *frontend*) echo "web" ;;
        *ui*) echo "web" ;;
        *) echo "" ;;
    esac
}

# Interactive type selection
select_project_type() {
    local detected="$1"
    local available_types
    mapfile -t available_types < <(get_available_types)

    if [[ "$detected" == "api" ]]; then
        print_status "Detected API project. What kind of API?"
        echo "Common choices for APIs:"
        echo "  1) node     - Node.js/Express API"
        echo "  2) python   - Python/FastAPI or Django REST"
        echo "  3) go       - Go API server"
        echo "  4) spring   - Spring Boot API"
        echo "  5) dotnet   - .NET Web API"
        echo ""
        read -r -p "Enter choice (1-5) or type name: " choice

        case "$choice" in
            1) echo "node" ;;
            2) echo "python" ;;
            3) echo "go" ;;
            4) echo "spring" ;;
            5) echo "dotnet" ;;
            *) echo "$choice" ;;
        esac
    elif [[ "$detected" == "web" ]]; then
        print_status "Detected web project. What framework?"
        echo "Common choices for web apps:"
        echo "  1) node     - Node.js/Express"
        echo "  2) rails    - Ruby on Rails"
        echo "  3) django   - Django"
        echo "  4) dotnet   - ASP.NET Core"
        echo ""
        read -r -p "Enter choice (1-4) or type name: " choice

        case "$choice" in
            1) echo "node" ;;
            2) echo "rails" ;;
            3) echo "django" ;;
            4) echo "dotnet" ;;
            *) echo "$choice" ;;
        esac
    else
        print_status "Available project types:"
        printf "%s\n" "${available_types[@]}" | pr -t -3
        echo ""
        read -r -p "Enter project type [default: node]: " input
        echo "${input:-node}"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <project_name> [options]"
    echo ""
    echo "Options:"
    echo "  --type <type>              Specify project type explicitly"
    echo "  --list-types               Show all available project types"
    echo "  --interactive              Force interactive type selection"
    echo "  --git-name <name>          Git user name for this project"
    echo "  --git-email <email>        Git user email for this project"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Auto-detection Examples:"
    echo "  $0 my-rails-app            # Detects Rails"
    echo "  $0 api-server              # Prompts for API type"
    echo "  $0 terraform-infra         # Detects Terraform"
    echo ""
    echo "Explicit Type Examples:"
    echo "  $0 my-app --type python"
    echo "  $0 my-app --type spring --git-name \"John Doe\""

    if [[ -f "$TEMPLATES_CONFIG" ]]; then
        echo ""
        echo "Available Types:"
        get_available_types | pr -t -4
    fi
    exit 1
}

# List available types
list_types() {
    echo "Available Project Types:"
    echo ""

    if [[ -f "$TEMPLATES_CONFIG" ]]; then
        local types
        mapfile -t types < <(get_available_types)
        for type in "${types[@]}"; do
            local desc
            desc=$(awk "/^  ${type}:/{flag=1; next} flag && /description:/{gsub(/.*description: *[\"']?/, \"\"); gsub(/[\"'].*$/, \"\"); print; exit}" "$TEMPLATES_CONFIG")
            printf "  %-12s %s\n" "$type" "$desc"
        done
    else
        echo "  node         Node.js application"
        echo "  python       Python application"
        echo "  go           Go application"
        echo "  rust         Rust application"
        echo "  web          Static web application"
    fi

    echo ""
    echo "Detection Patterns:"
    echo "  *rails*      → rails"
    echo "  *django*     → django"
    echo "  *spring*     → spring"
    echo "  *terraform*  → terraform"
    echo "  *api*        → interactive API selection"
    echo "  *web*        → interactive web selection"

    exit 0
}

# Parse arguments
if [ $# -eq 0 ]; then
    show_usage
fi

# Handle special flags first
case "$1" in
    --list-types)
        list_types
        ;;
    -h|--help)
        show_usage
        ;;
esac

PROJECT_NAME="$1"
shift

# Parse optional arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            PROJECT_TYPE="$2"
            AUTO_DETECT=false
            shift 2
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --list-types)
            list_types
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

# Determine project type
if [[ "$AUTO_DETECT" == "true" ]] && [[ -z "$PROJECT_TYPE" ]]; then
    DETECTED_TYPE=$(detect_project_type "$PROJECT_NAME")

    if [[ -n "$DETECTED_TYPE" ]] && [[ "$DETECTED_TYPE" != "api" ]] && [[ "$DETECTED_TYPE" != "web" ]] && [[ "$INTERACTIVE" != "true" ]]; then
        PROJECT_TYPE="$DETECTED_TYPE"
        print_status "Auto-detected project type: $PROJECT_TYPE"
    else
        PROJECT_TYPE=$(select_project_type "$DETECTED_TYPE")
    fi
fi

# Default to node if still no type
if [[ -z "$PROJECT_TYPE" ]]; then
    PROJECT_TYPE="node"
fi

# Validate project type
if [[ -f "$TEMPLATES_CONFIG" ]]; then
    if ! get_available_types | grep -q "^${PROJECT_TYPE}$"; then
        print_warning "Unknown project type: $PROJECT_TYPE"
        print_status "Available types: $(get_available_types | tr '\n' ' ')"
        PROJECT_TYPE=$(select_project_type "")
    fi
fi

# Function to activate extensions based on template
activate_extensions() {
    local project_type="$1"
    if [[ ! -f "$TEMPLATES_CONFIG" ]]; then
        return
    fi

    # Extract extensions for the project type
    local extensions_line
    extensions_line=$(awk "/^  ${project_type}:/{flag=1; next} flag && /^    extensions:/{print; exit}" "$TEMPLATES_CONFIG")
    if [[ -n "$extensions_line" ]]; then
        # Parse the YAML array - simple approach
        local extensions
        extensions=$(echo "$extensions_line" | sed 's/.*extensions: *\[\(.*\)\].*/\1/' | tr ',' '\n' | sed 's/[" ]//g')

        if [[ -n "$extensions" ]] && [[ "$extensions" != "[]" ]]; then
            print_status "Activating extensions for $project_type..."

            while IFS= read -r ext; do
                if [[ -n "$ext" ]] && [[ "$ext" != "[]" ]]; then
                    local src_file="${EXTENSIONS_DIR}/${ext}.example"
                    local dest_file="${EXTENSIONS_DIR}/${ext}"

                    if [[ -f "$src_file" ]] && [[ ! -f "$dest_file" ]]; then
                        print_debug "Activating extension: $ext"
                        cp "$src_file" "$dest_file" 2>/dev/null || print_warning "Failed to activate extension: $ext"
                    fi
                fi
            done <<< "$extensions"
        fi
    fi
}

# Function to create project from template
create_from_template() {
    local project_type="$1"
    local project_name="$2"

    if [[ ! -f "$TEMPLATES_CONFIG" ]]; then
        # Fallback to legacy behavior
        create_legacy_project "$project_type"
        return
    fi

    # Extract setup commands
    print_status "Setting up $project_type project structure..."

    # Simple YAML parsing for setup commands
    awk "
        /^  ${project_type}:/ { in_template=1; next }
        in_template && /^  [a-zA-Z]/ && !/^    / { exit }
        in_template && /^    setup_commands:/ { in_setup=1; next }
        in_template && in_setup && /^    files:/ { in_setup=0; in_files=1; next }
        in_template && in_setup && /^      - / {
            cmd = \$0; gsub(/^      - \"/, \"\", cmd); gsub(/\"$/, \"\", cmd);
            gsub(/{project_name}/, \"$project_name\", cmd);
            print cmd
        }
    " "$TEMPLATES_CONFIG" | while IFS= read -r cmd; do
        if [[ -n "$cmd" ]]; then
            print_debug "Running: $cmd"
            eval "$cmd" 2>/dev/null || print_warning "Command failed: $cmd"
        fi
    done

    # Create files from template
    local temp_file="/tmp/template_files_$$"
    awk "
        /^  ${project_type}:/ { in_template=1; next }
        in_template && /^  [a-zA-Z]/ && !/^    / { exit }
        in_template && /^    files:/ { in_files=1; next }
        in_template && in_files && /^      \".*\":/ {
            file = \$0; gsub(/^      \"/, \"\", file); gsub(/\": *\|?$/, \"\", file);
            gsub(/{project_name}/, \"$project_name\", file);
            print \"FILE:\" file; in_content=1; next
        }
        in_template && in_files && in_content && /^        / {
            content = \$0; gsub(/^        /, \"\", content);
            gsub(/{project_name}/, \"$project_name\", content);
            print content
        }
        in_template && in_files && !/^        / && !/^      \"/ { in_content=0 }
    " "$TEMPLATES_CONFIG" > "$temp_file"

    local current_file=""
    while IFS= read -r line; do
        if [[ "$line" =~ ^FILE: ]]; then
            current_file="${line#FILE:}"
            [[ -n "$current_file" ]] && mkdir -p "$(dirname "$current_file")"
        elif [[ -n "$current_file" ]]; then
            echo "$line" >> "$current_file"
        fi
    done < "$temp_file"

    rm -f "$temp_file"
}

# Function for legacy project creation (fallback)
create_legacy_project() {
    local project_type="$1"

    case $project_type in
        node)
            npm init -y
            ;;
        python)
            python3 -m venv venv 2>/dev/null || true
            touch requirements.txt
            ;;
        go)
            go mod init "$PROJECT_NAME" 2>/dev/null || echo "module $PROJECT_NAME" > go.mod
            ;;
        rust)
            cargo init --name "$PROJECT_NAME" 2>/dev/null || {
                {
                    echo "[package]"
                    echo "name = \"$PROJECT_NAME\""
                    echo "version = \"0.1.0\""
                    echo "edition = \"2021\""
                } > Cargo.toml
                mkdir -p src
                echo "fn main() { println!(\"Hello, world!\"); }" > src/main.rs
            }
            ;;
        web)
            mkdir -p src css js
            touch src/index.html css/style.css js/app.js
            ;;
        rails)
            if command_exists rails; then
                rails new . --skip-git --force 2>/dev/null || print_warning "Rails not available, creating basic structure"
            else
                mkdir -p app/{controllers,models,views} config db
                touch Gemfile
            fi
            ;;
        django)
            if command_exists django-admin; then
                django-admin startproject "$PROJECT_NAME" . 2>/dev/null || print_warning "Django not available"
            else
                mkdir -p "$PROJECT_NAME" static templates
                touch requirements.txt manage.py
            fi
            ;;
        *)
            print_warning "Unknown project type: $project_type, creating basic structure"
            touch README.md
            ;;
    esac
}

# Function to create CLAUDE.md from template
create_claude_md() {
    local project_type="$1"
    local project_name="$2"

    if [[ -f "$TEMPLATES_CONFIG" ]]; then
        # Extract Claude.md template from YAML
        awk "
            /^  ${project_type}:/ { in_template=1; next }
            in_template && /^  [a-zA-Z]/ && !/^    / { exit }
            in_template && /^    claude_md_template: *\|/ { in_claude=1; next }
            in_template && in_claude && /^      / {
                content = \$0; gsub(/^      /, \"\", content);
                gsub(/{project_name}/, \"$project_name\", content);
                print content
            }
            in_template && in_claude && !/^      / { exit }
        " "$TEMPLATES_CONFIG" > CLAUDE.md

        # If template was empty or not found, create default
        if [[ ! -s CLAUDE.md ]]; then
            create_default_claude_md "$project_type" "$project_name"
        fi
    else
        create_default_claude_md "$project_type" "$project_name"
    fi
}

# Function to create default CLAUDE.md
create_default_claude_md() {
    local project_type="$1"
    local project_name="$2"

    cat > CLAUDE.md << CLAUDE_EOF
# $project_name

## Project Overview
This is a $project_type project for [brief description].

## Setup Instructions
[Add setup instructions here]

## Development Commands
[Add common commands here]

## Architecture Notes
[Add architectural decisions and patterns]

## Important Files
[List key files and their purposes]
CLAUDE_EOF
}

PROJECT_DIR="${PROJECTS_DIR:-/workspace/projects}/active/$PROJECT_NAME"

if [ -d "$PROJECT_DIR" ]; then
    print_error "Project $PROJECT_NAME already exists"
    exit 1
fi

print_status "Creating new $PROJECT_TYPE project: $PROJECT_NAME"

# Activate relevant extensions first
activate_extensions "$PROJECT_TYPE"

# Create project directory
create_directory "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit 1

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

# Create project structure from template
create_from_template "$PROJECT_TYPE" "$PROJECT_NAME"

# Create CLAUDE.md for project context
create_claude_md "$PROJECT_TYPE" "$PROJECT_NAME"

# Add and commit the new files
git add .
git commit -m "feat: initial project setup for $PROJECT_NAME"

# Initialize GitHub spec-kit if available
if command_exists uvx || command_exists uv; then
    print_status "Initializing GitHub spec-kit..."
    if uvx --from git+https://github.com/github/spec-kit.git specify init --here 2>/dev/null; then
        print_success "GitHub spec-kit initialized"
        # Add spec-kit files if any were created
        if [[ -n "$(git status --porcelain)" ]]; then
            git add .
            git commit -m "feat: add GitHub spec-kit configuration" 2>/dev/null || true
        fi
    else
        print_debug "GitHub spec-kit initialization skipped (uvx not available or failed)"
    fi
fi

# Initialize Claude Flow if available
if command_exists claude-flow || command_exists npx; then
    print_status "Initializing Claude Flow..."
    if npx claude-flow@alpha init --force 2>/dev/null; then
        print_success "Claude Flow initialized"
    else
        print_debug "Claude Flow initialization skipped"
    fi
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