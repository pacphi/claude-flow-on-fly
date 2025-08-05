#!/bin/bash
# vm-teardown.sh - Teardown script for Claude Development Environment on Fly.io
# This script safely removes the Fly.io VM, volumes, and associated resources
# WARNING: This will permanently delete all data unless backed up first

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
APP_NAME="${APP_NAME:-}"
FORCE_DELETE=false
BACKUP_FIRST=false
DELETE_APP=true
DELETE_VOLUMES=true
DELETE_SECRETS=true

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

# Function to check if app exists
check_app_exists() {
    if [[ -z "$APP_NAME" ]]; then
        print_error "No app name specified."
        print_status "Usage: $0 --app-name <name>"
        exit 1
    fi

    if ! flyctl apps list | grep -q "^$APP_NAME"; then
        print_warning "Application $APP_NAME not found."
        print_status "Nothing to teardown."
        exit 0
    fi

    print_success "Found application: $APP_NAME"
}

# Function to show app information before deletion
show_app_info() {
    print_status "Application Details:"
    echo

    # Show app status
    print_status "App Status:"
    # Use a temp directory to avoid fly.toml parsing issues
    local original_dir=$(pwd)
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    if flyctl status -a "$APP_NAME" 2>&1; then
        :
    else
        local exit_code=$?
        if [[ $exit_code -eq 1 ]]; then
            echo "  (No active machines found)"
        else
            print_warning "  Failed to get app status (flyctl exit code: $exit_code)"
        fi
    fi
    echo

    # Show machines
    print_status "Machines:"
    local machine_output
    if machine_output=$(flyctl machine list -a "$APP_NAME" 2>&1); then
        if [[ -n "$machine_output" ]]; then
            echo "$machine_output"
        else
            echo "  (No machines found)"
        fi
    else
        local exit_code=$?
        if echo "$machine_output" | grep -q "No machines found"; then
            echo "  (No machines found)"
        else
            print_warning "  Failed to list machines (flyctl exit code: $exit_code)"
            [[ -n "$machine_output" ]] && echo "  $machine_output" | head -2
        fi
    fi
    echo

    # Show volumes
    print_status "Volumes:"
    local volume_output
    if volume_output=$(flyctl volumes list -a "$APP_NAME" 2>&1); then
        if [[ -n "$volume_output" ]] && ! echo "$volume_output" | grep -q "No volumes found"; then
            echo "$volume_output"
        else
            echo "  (No volumes found)"
        fi
    else
        local exit_code=$?
        if echo "$volume_output" | grep -q "No volumes found"; then
            echo "  (No volumes found)"
        else
            print_warning "  Failed to list volumes (flyctl exit code: $exit_code)"
            [[ -n "$volume_output" ]] && echo "  $volume_output" | head -2
        fi
    fi

    # Return to original directory
    cd "$original_dir"
    echo

    # Calculate approximate costs being saved
    local machine_count
    local volume_count

    # Count machines with proper error handling (run from temp dir to avoid fly.toml issues)
    cd "$temp_dir"
    machine_count=$(flyctl machine list -a "$APP_NAME" 2>/dev/null | grep -c "started\|stopped" 2>/dev/null || echo "0")
    machine_count=${machine_count//[^0-9]/}  # Strip any non-numeric characters
    machine_count=$((machine_count + 0))     # Convert to integer, handles "00" -> 0

    # Count volumes with proper error handling
    volume_count=$(flyctl volumes list -a "$APP_NAME" 2>/dev/null | grep -c "created" 2>/dev/null || echo "0")
    volume_count=${volume_count//[^0-9]/}    # Strip any non-numeric characters
    volume_count=$((volume_count + 0))       # Convert to integer, handles "00" -> 0

    cd "$original_dir"
    rm -rf "$temp_dir"

    if [[ $machine_count -gt 0 ]] || [[ $volume_count -gt 0 ]]; then
        print_status "💰 Estimated Monthly Cost Savings:"
        if [[ $machine_count -gt 0 ]]; then
            echo "  • VM costs: ~\$5-30/month (depending on usage)"
        fi
        if [[ $volume_count -gt 0 ]]; then
            # Try to get volume size (portable approach)
            local volume_size
            volume_size=$(flyctl volumes list -a "$APP_NAME" 2>/dev/null | grep -o '[0-9]*GB' | head -1 | sed 's/GB//' 2>/dev/null || echo "10")
            volume_size=${volume_size//[^0-9]/}  # Strip any non-numeric characters
            volume_size=${volume_size:-10}       # Default to 10GB if empty

            # Calculate volume cost using bash arithmetic (volume_size * 0.15)
            local volume_cost_cents=$((volume_size * 15))
            local volume_cost
            # Handle cost formatting - convert cents to dollars.cents
            if [[ $volume_cost_cents -lt 100 ]]; then
                # Less than $1.00 - format as 0.XX
                volume_cost=$(printf "0.%02d" $volume_cost_cents)
            else
                # $1.00 or more - split into dollars and cents
                local dollars=$((volume_cost_cents / 100))
                local cents=$((volume_cost_cents % 100))
                volume_cost=$(printf "%d.%02d" $dollars $cents)
            fi
            echo "  • Volume costs: ~\$$volume_cost/month"
        fi
        echo
    fi
}

# Function to backup data before deletion
backup_data() {
    print_status "Creating backup before teardown..."

    # Check if backup script exists
    if [[ -f "./scripts/volume-backup.sh" ]]; then
        print_status "Running volume backup..."
        ./scripts/volume-backup.sh --app-name "$APP_NAME" || {
            print_error "Backup failed!"
            if [[ "$FORCE_DELETE" != true ]]; then
                print_status "Aborting teardown. Use --force to skip backup."
                exit 1
            else
                print_warning "Continuing with teardown despite backup failure (--force mode)"
            fi
        }
        print_success "Backup completed"
    else
        print_warning "Backup script not found. Skipping backup."
        if [[ "$FORCE_DELETE" != true ]]; then
            read -p "Continue without backup? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Teardown cancelled"
                exit 0
            fi
        fi
    fi
}

# Function to suspend machines before deletion
suspend_machines() {
    print_status "Suspending running machines..."

    # Use temp dir to avoid fly.toml parsing issues
    local original_dir=$(pwd)
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    local machines=$(flyctl machine list -a "$APP_NAME" --json 2>/dev/null | jq -r '.[] | select(.state == "started") | .id' || true)

    cd "$original_dir"
    rm -rf "$temp_dir"

    if [[ -n "$machines" ]]; then
        for machine_id in $machines; do
            print_status "Stopping machine: $machine_id"
            flyctl machine stop "$machine_id" -a "$APP_NAME" || true
        done
        print_success "All machines stopped"
    else
        print_status "No running machines to stop"
    fi
}

# Function to delete volumes
delete_volumes() {
    if [[ "$DELETE_VOLUMES" != true ]]; then
        print_status "Skipping volume deletion (--keep-volumes specified)"
        return
    fi

    print_status "Deleting persistent volumes..."

    # Use temp dir to avoid fly.toml parsing issues
    local original_dir=$(pwd)
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    local volumes=$(flyctl volumes list -a "$APP_NAME" --json 2>/dev/null | jq -r '.[].id' || true)

    cd "$original_dir"
    rm -rf "$temp_dir"

    if [[ -n "$volumes" ]]; then
        for volume_id in $volumes; do
            print_status "Deleting volume: $volume_id"
            if [[ "$FORCE_DELETE" == true ]]; then
                flyctl volumes delete "$volume_id" -a "$APP_NAME" --yes || true
            else
                flyctl volumes delete "$volume_id" -a "$APP_NAME" || true
            fi
        done
        print_success "All volumes deleted"
    else
        print_status "No volumes to delete"
    fi
}

# Function to delete the app
delete_app() {
    if [[ "$DELETE_APP" != true ]]; then
        print_status "Skipping app deletion (--keep-app specified)"
        return
    fi

    print_status "Deleting Fly.io application: $APP_NAME"

    if [[ "$FORCE_DELETE" == true ]]; then
        flyctl apps destroy "$APP_NAME" --yes || {
            print_error "Failed to delete app $APP_NAME"
            exit 1
        }
    else
        flyctl apps destroy "$APP_NAME" || {
            print_error "Failed to delete app $APP_NAME"
            exit 1
        }
    fi

    print_success "Application $APP_NAME deleted"
}

# Function to clean up local files
cleanup_local_files() {
    print_status "Cleaning up local configuration files..."

    # Restore original fly.toml if backup exists
    if [[ -f "fly.toml.backup" ]]; then
        print_status "Restoring original fly.toml from backup"
        mv fly.toml.backup fly.toml
        print_success "fly.toml restored"
    fi

    # Remove app-specific SSH config if it exists
    if [[ -f "$HOME/.ssh/config" ]] && grep -q "Host $APP_NAME" "$HOME/.ssh/config"; then
        print_warning "Found SSH config entry for $APP_NAME"
        print_status "You may want to manually remove it from ~/.ssh/config"
    fi
}

# Function to show final summary
show_summary() {
    echo
    print_success "🎯 Teardown Complete!"
    echo
    print_status "Resources Deleted:"
    echo "  ✓ Fly.io app: $APP_NAME"
    if [[ "$DELETE_VOLUMES" == true ]]; then
        echo "  ✓ Persistent volumes"
    fi
    if [[ "$DELETE_SECRETS" == true ]]; then
        echo "  ✓ Application secrets"
    fi
    echo

    if [[ "$BACKUP_FIRST" == true ]]; then
        print_status "📦 Backup Information:"
        echo "  Your data has been backed up locally"
        echo "  Check ./backups/ directory for backup files"
        echo
    fi

    print_status "💰 Cost Savings:"
    echo "  You've stopped all charges for this environment"
    echo "  No more VM or volume costs for $APP_NAME"
    echo

    print_status "🔄 To recreate this environment:"
    echo "  ./scripts/vm-setup.sh --app-name $APP_NAME"
    if [[ "$BACKUP_FIRST" == true ]]; then
        echo "  ./scripts/volume-restore.sh --app-name $APP_NAME"
    fi
}

# Main execution function
main() {
    echo "🗑️  Teardown Claude Development Environment on Fly.io"
    echo "=================================================="
    echo

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-name)
                APP_NAME="$2"
                shift 2
                ;;
            --force)
                FORCE_DELETE=true
                shift
                ;;
            --backup)
                BACKUP_FIRST=true
                shift
                ;;
            --keep-volumes)
                DELETE_VOLUMES=false
                shift
                ;;
            --keep-app)
                DELETE_APP=false
                shift
                ;;
            --keep-secrets)
                DELETE_SECRETS=false
                shift
                ;;
            --help)
                cat << EOF
Usage: $0 --app-name NAME [OPTIONS]

Required:
  --app-name NAME     Name of the Fly.io app to teardown

Options:
  --force             Skip confirmation prompts (dangerous!)
  --backup            Create backup before teardown
  --keep-volumes      Don't delete persistent volumes
  --keep-app          Don't delete the app (only stop machines)
  --keep-secrets      Don't delete application secrets
  --help              Show this help message

Examples:
  # Standard teardown with confirmations
  $0 --app-name my-claude-dev

  # Teardown with automatic backup first
  $0 --app-name my-claude-dev --backup

  # Force teardown without prompts (use with caution!)
  $0 --app-name my-claude-dev --force

  # Keep volumes but delete everything else
  $0 --app-name my-claude-dev --keep-volumes

WARNING: This will permanently delete all data unless you:
  1. Use --backup flag to create a backup first
  2. Manually backup your data before running this script
  3. Use --keep-volumes to preserve persistent storage

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

    # Check prerequisites
    check_flyctl
    check_app_exists

    # Show what will be deleted
    show_app_info

    # Confirm deletion
    if [[ "$FORCE_DELETE" != true ]]; then
        print_warning "⚠️  THIS WILL PERMANENTLY DELETE THE FOLLOWING:"
        echo "  • Fly.io application: $APP_NAME"
        if [[ "$DELETE_VOLUMES" == true ]]; then
            echo "  • All persistent volumes and data"
        fi
        if [[ "$DELETE_SECRETS" == true ]]; then
            echo "  • All application secrets"
        fi
        echo "  • All running machines and resources"
        echo
        print_warning "This action cannot be undone!"
        echo

        if [[ "$BACKUP_FIRST" != true ]]; then
            read -p "Do you want to create a backup first? (Y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                BACKUP_FIRST=true
            fi
        fi

        read -p "Are you sure you want to proceed with teardown? Type 'yes' to confirm: " -r
        if [[ "$REPLY" != "yes" ]]; then
            print_status "Teardown cancelled"
            exit 0
        fi
    fi

    # Create backup if requested
    if [[ "$BACKUP_FIRST" == true ]]; then
        backup_data
    fi

    # Perform teardown
    suspend_machines

    # Delete volumes before app (volumes can only be deleted when app exists)
    if [[ "$DELETE_VOLUMES" == true ]]; then
        delete_volumes
    fi

    # Delete the app (this also deletes machines and secrets)
    if [[ "$DELETE_APP" == true ]]; then
        delete_app
    fi

    # Clean up local files
    cleanup_local_files

    # Show summary
    show_summary

    print_success "✨ Teardown completed successfully!"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi