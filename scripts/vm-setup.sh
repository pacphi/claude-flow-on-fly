#!/bin/bash
# vm-setup.sh - Initial setup script for Claude Development Environment on Fly.io
# This script helps set up the Fly.io VM with all necessary tools and configurations

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables (can be overridden with environment variables)
APP_NAME="${APP_NAME:-claude-dev-env}"
REGION="${REGION:-iad}"
VM_SIZE="${VM_SIZE:-shared-cpu-1x}"
VM_MEMORY="${VM_MEMORY:-1024}"
VOLUME_SIZE="${VOLUME_SIZE:-10}"
VOLUME_NAME="${VOLUME_NAME:-claude_data}"

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

# Function to check if flyctl is installed and authenticated
check_flyctl() {
    if ! command_exists flyctl; then
        print_error "Fly.io CLI (flyctl) is not installed."
        print_status "Please install it from: https://fly.io/docs/getting-started/installing-flyctl/"
        exit 1
    fi

    # Check if authenticated
    if ! flyctl auth whoami >/dev/null 2>&1; then
        print_error "You are not authenticated with Fly.io."
        print_status "Please run: flyctl auth login"
        exit 1
    fi

    print_success "Fly.io CLI is installed and authenticated"
}

# Function to check for required files
check_required_files() {
    local missing_files=()

    if [[ ! -f "Dockerfile" ]]; then
        missing_files+=("Dockerfile")
    fi

    if [[ ! -f "fly.toml" ]]; then
        missing_files+=("fly.toml")
    fi

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "Missing required files: ${missing_files[*]}"
        print_status "Please ensure you have the following files in the current directory:"
        print_status "  - Dockerfile (container configuration)"
        print_status "  - fly.toml (Fly.io application configuration)"
        exit 1
    fi

    print_success "All required files found"
}

# Function to check SSH key
check_ssh_key() {
    local ssh_key_path="$HOME/.ssh/id_rsa.pub"

    if [[ ! -f "$ssh_key_path" ]]; then
        print_warning "SSH public key not found at $ssh_key_path"
        print_status "Checking for other SSH keys..."

        # Look for other common SSH key names
        for key_type in id_ed25519 id_ecdsa id_dsa; do
            if [[ -f "$HOME/.ssh/${key_type}.pub" ]]; then
                ssh_key_path="$HOME/.ssh/${key_type}.pub"
                print_success "Found SSH key: $ssh_key_path"
                break
            fi
        done

        if [[ ! -f "$ssh_key_path" ]]; then
            print_error "No SSH public key found."
            print_status "Please generate an SSH key pair:"
            print_status "  ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519"
            print_status "  OR"
            print_status "  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa"
            exit 1
        fi
    fi

    export SSH_KEY_PATH="$ssh_key_path"
    print_success "SSH key found: $ssh_key_path"
}

# Function to create Fly.io application
create_fly_app() {
    print_status "Creating Fly.io application: $APP_NAME"

    # Check if app already exists
    if flyctl apps list | grep -q "^$APP_NAME"; then
        print_warning "Application $APP_NAME already exists"
        read -p "Do you want to continue with the existing app? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Exiting. Please choose a different APP_NAME or delete the existing app."
            exit 1
        fi
    else
        # Create new app
        flyctl apps create "$APP_NAME" --org personal
        print_success "Created application: $APP_NAME"
    fi
}

# Function to create persistent volume
create_volume() {
    print_status "Creating persistent volume: $VOLUME_NAME"

    # Check if volume already exists
    if flyctl volumes list -a "$APP_NAME" | grep -q "$VOLUME_NAME"; then
        print_warning "Volume $VOLUME_NAME already exists"
        flyctl volumes list -a "$APP_NAME"
        read -p "Do you want to continue with the existing volume? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Exiting. Please choose a different VOLUME_NAME or delete the existing volume."
            exit 1
        fi
    else
        # Create new volume
        flyctl volumes create "$VOLUME_NAME" \
            --app "$APP_NAME" \
            --region "$REGION" \
            --size "$VOLUME_SIZE" \
            --no-encryption
        print_success "Created volume: $VOLUME_NAME ($VOLUME_SIZE GB)"
    fi
}

# Function to configure secrets
configure_secrets() {
    print_status "Configuring SSH keys and secrets"

    # Set SSH authorized keys
    local ssh_key_content
    ssh_key_content=$(cat "$SSH_KEY_PATH")
    flyctl secrets set AUTHORIZED_KEYS="$ssh_key_content" -a "$APP_NAME"
    print_success "SSH keys configured"

    # Optionally set Anthropic API key
    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        flyctl secrets set ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" -a "$APP_NAME"
        print_success "Anthropic API key configured"
    else
        print_warning "ANTHROPIC_API_KEY not set. You can set it later with:"
        print_warning "  flyctl secrets set ANTHROPIC_API_KEY=your_api_key -a $APP_NAME"
    fi
}

# Function to update fly.toml with correct app name
update_fly_toml() {
    print_status "Updating fly.toml with app name and configuration"

    # Backup original fly.toml
    cp fly.toml fly.toml.backup

    # Replace all placeholder values with actual configuration
    sed -i.tmp "s/{{APP_NAME}}/$APP_NAME/g" fly.toml
    rm fly.toml.tmp

    sed -i.tmp "s/{{REGION}}/$REGION/g" fly.toml
    rm fly.toml.tmp

    sed -i.tmp "s/{{VOLUME_NAME}}/$VOLUME_NAME/g" fly.toml
    rm fly.toml.tmp

    sed -i.tmp "s/{{VM_MEMORY}}/$VM_MEMORY/g" fly.toml
    rm fly.toml.tmp

    print_success "fly.toml updated"
}

# Function to deploy application
deploy_app() {
    print_status "Deploying application to Fly.io"

    # Deploy the application
    flyctl deploy -a "$APP_NAME"

    print_success "Application deployed successfully"
}

# Function to show connection information
show_connection_info() {
    print_success "Setup complete! Here's how to connect:"
    echo
    print_status "SSH Connection:"
    echo "  ssh developer@$APP_NAME.fly.dev -p 10022"
    echo
    print_status "SSH Config Entry (add to ~/.ssh/config):"
    echo "  Host $APP_NAME"
    echo "      HostName $APP_NAME.fly.dev"
    echo "      Port 10022"
    echo "      User developer"
    echo "      IdentityFile $SSH_KEY_PATH"
    echo "      ServerAliveInterval 60"
    echo
    print_status "Useful Commands:"
    echo "  flyctl status -a $APP_NAME        # Check app status"
    echo "  flyctl logs -a $APP_NAME          # View logs"
    echo "  flyctl ssh console -a $APP_NAME   # Direct SSH access"
    echo "  flyctl machine list -a $APP_NAME  # List machines"
    echo "  flyctl volumes list -a $APP_NAME  # List volumes"
    echo
    print_status "Next Steps:"
    echo "  1. Connect via SSH or IDE remote development"
    echo "  2. Run: /workspace/scripts/install-claude-tools.sh"
    echo "  3. Authenticate Claude: claude"
    echo "  4. Start developing!"
}

# Function to show cost information
show_cost_info() {
    echo
    print_status "💰 Cost Information:"
    echo "  • VM (when running): ~\$0.0067/hour (\$5/month if always on)"
    echo "  • Volume ($VOLUME_SIZE GB): \$$(echo "$VOLUME_SIZE * 0.15" | bc)/month"
    echo "  • With auto-suspend: ~\$2-5/month total"
    echo "  • Scale to zero: Only pay for storage when idle"
    echo
    print_warning "💡 Volume costs persist even when VM is stopped!"
}

# Main execution function
main() {
    echo "🚀 Setting up Claude Development Environment on Fly.io"
    echo "=================================================="
    echo

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-name)
                APP_NAME="$2"
                shift 2
                ;;
            --region)
                REGION="$2"
                shift 2
                ;;
            --volume-size)
                VOLUME_SIZE="$2"
                shift 2
                ;;
            --memory)
                VM_MEMORY="$2"
                shift 2
                ;;
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --app-name NAME     Name for the Fly.io app (default: claude-dev-env)
  --region REGION     Fly.io region (default: iad)
  --volume-size SIZE  Volume size in GB (default: 10)
  --memory SIZE       VM memory in MB (default: 1024)
  --help              Show this help message

Environment Variables:
  ANTHROPIC_API_KEY   Your Anthropic API key (optional)

Examples:
  $0
  $0 --app-name my-dev --region sjc --volume-size 20
  ANTHROPIC_API_KEY=sk-ant-... $0 --app-name claude-dev

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

    print_status "Configuration:"
    echo "  App Name: $APP_NAME"
    echo "  Region: $REGION"
    echo "  Volume Size: ${VOLUME_SIZE}GB"
    echo "  VM Memory: ${VM_MEMORY}MB"
    echo

    # Confirm before proceeding
    read -p "Continue with this configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Setup cancelled"
        exit 0
    fi

    # Run setup steps
    check_flyctl
    check_required_files
    check_ssh_key
    create_fly_app
    create_volume
    configure_secrets
    update_fly_toml
    deploy_app

    # Show connection information
    show_connection_info
    show_cost_info

    print_success "🎉 Setup complete! Your Claude development environment is ready."
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi