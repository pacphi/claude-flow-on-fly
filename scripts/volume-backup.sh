#!/bin/bash
# volume-backup.sh - Backup Fly.io volume data to external storage
# This script runs on your LOCAL machine to backup VM data

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_NAME="${APP_NAME:-claude-dev-env}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
REMOTE_USER="developer"
REMOTE_HOST="$APP_NAME.fly.dev"
REMOTE_PORT="10022"

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

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    # Check if flyctl is available
    if ! command -v flyctl >/dev/null 2>&1; then
        print_error "flyctl not found. Please install Fly.io CLI."
        exit 1
    fi

    # Check if rsync is available
    if ! command -v rsync >/dev/null 2>&1; then
        print_error "rsync not found. Please install rsync."
        exit 1
    fi

    # Check if app exists
    if ! flyctl apps list | grep -q "^$APP_NAME"; then
        print_error "App $APP_NAME not found."
        exit 1
    fi

    # Create local backup directory
    mkdir -p "$BACKUP_DIR"

    print_success "Prerequisites checked"
}

# Function to check VM status
check_vm_status() {
    print_status "Checking VM status..."

    # Check if VM is running
    local machine_status
    machine_status=$(flyctl machine list -a "$APP_NAME" --json | jq -r '.[0].state' 2>/dev/null || echo "unknown")

    if [[ "$machine_status" != "started" ]]; then
        print_warning "VM is not running (status: $machine_status)"
        read -p "Start the VM? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_status "Starting VM..."
            flyctl machine start -a "$APP_NAME" "$(flyctl machine list -a "$APP_NAME" --json | jq -r '.[0].id')"

            # Wait for SSH to be available
            print_status "Waiting for SSH to be available..."
            local retries=0
            while [[ $retries -lt 30 ]]; do
                if ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" exit 2>/dev/null; then
                    break
                fi
                sleep 2
                ((retries++))
            done

            if [[ $retries -eq 30 ]]; then
                print_error "VM failed to start or SSH is not accessible"
                exit 1
            fi
        else
            print_error "Cannot backup - VM is not running"
            exit 1
        fi
    fi

    print_success "VM is running and accessible"
}

# Function to create remote backup
create_remote_backup() {
    print_status "Creating backup on remote VM..."

    local backup_date
    backup_date=$(date +%Y%m%d_%H%M%S)
    local remote_backup_name="backup_${APP_NAME}_${backup_date}.tar.gz"

    # Create backup on remote VM - all output to stderr except the filename
    {
        ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" bash << EOF
set -e

# Define directories to backup
BACKUP_DIRS="/workspace/projects /workspace/.config /workspace/developer/.claude /workspace/scripts"
BACKUP_FILE="/workspace/backups/$remote_backup_name"

# Create backups directory
mkdir -p /workspace/backups

# Show progress
echo "🔄 Creating remote backup..."

# Create compressed backup
tar --exclude='/workspace/backups' \\
    --exclude='/workspace/.cache' \\
    --exclude='node_modules' \\
    --exclude='.git/objects' \\
    --exclude='*.log' \\
    -czf "\$BACKUP_FILE" \$BACKUP_DIRS 2>/dev/null || {
    echo "⚠️ Some files may not be accessible, continuing..."
    tar --ignore-failed-read \\
        --exclude='/workspace/backups' \\
        --exclude='/workspace/.cache' \\
        --exclude='node_modules' \\
        --exclude='.git/objects' \\
        --exclude='*.log' \\
        -czf "\$BACKUP_FILE" \$BACKUP_DIRS
}

# Show backup info
echo "✅ Remote backup created: $remote_backup_name"
ls -lh "\$BACKUP_FILE"

# Keep only last 5 remote backups to save space
find /workspace/backups -name "backup_*.tar.gz" -type f | sort | head -n -5 | xargs -r rm

echo "📊 Remaining backups:"
ls -lh /workspace/backups/backup_*.tar.gz 2>/dev/null || echo "No backups found"
EOF
    } >&2  # Redirect all SSH output to stderr

    print_success "Remote backup created: $remote_backup_name"
    # Return just the filename on stdout for capture
    echo "$remote_backup_name"
}

# Function to download backup
download_backup() {
    local remote_backup_name="$1"
    local local_backup_path="$BACKUP_DIR/$remote_backup_name"

    print_status "Downloading backup to local machine..."

    # Download using rsync for reliability
    rsync -avz --progress \
        -e "ssh -p $REMOTE_PORT" \
        "$REMOTE_USER@$REMOTE_HOST:/workspace/backups/$remote_backup_name" \
        "$local_backup_path"

    print_success "Backup downloaded: $local_backup_path"

    # Show local backup info
    ls -lh "$local_backup_path"
}

# Function to sync entire workspace
sync_workspace() {
    print_status "Syncing entire workspace..."

    local sync_dir="$BACKUP_DIR/workspace_sync_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$sync_dir"

    # Sync workspace using rsync with exclusions
    rsync -avz --progress \
        --exclude='/workspace/backups' \
        --exclude='/workspace/.cache' \
        --exclude='node_modules' \
        --exclude='.git/objects' \
        --exclude='*.log' \
        --exclude='__pycache__' \
        -e "ssh -p $REMOTE_PORT" \
        "$REMOTE_USER@$REMOTE_HOST:/workspace/" \
        "$sync_dir/"

    print_success "Workspace synced to: $sync_dir"
}

# Function to list remote backups
list_remote_backups() {
    print_status "Remote backups:"

    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" \
        "ls -lh /workspace/backups/backup_*.tar.gz 2>/dev/null || echo 'No remote backups found'"
}

# Function to list local backups
list_local_backups() {
    print_status "Local backups:"

    ls -lh "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null || echo "No local backups found"
    echo

    if [[ -d "$BACKUP_DIR" ]]; then
        print_status "Local sync directories:"
        find "$BACKUP_DIR" -name "workspace_sync_*" -type d | sort
    fi
}

# Function to cleanup old backups
cleanup_backups() {
    local keep_count="${1:-5}"

    print_status "Cleaning up old local backups (keeping $keep_count)..."

    # Remove old local backup files
    if ls "$BACKUP_DIR"/backup_*.tar.gz >/dev/null 2>&1; then
        find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f | sort | head -n -"$keep_count" | xargs -r rm
        print_success "Old backup files cleaned up"
    fi

    # Remove old sync directories (keep 3)
    if find "$BACKUP_DIR" -name "workspace_sync_*" -type d >/dev/null 2>&1; then
        find "$BACKUP_DIR" -name "workspace_sync_*" -type d | sort | head -n -3 | xargs -r rm -rf
        print_success "Old sync directories cleaned up"
    fi
}

# Function to restore backup to VM
restore_backup() {
    local backup_file="$1"

    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        exit 1
    fi

    print_warning "This will restore data to the remote VM"
    print_warning "Current data may be overwritten!"
    read -p "Continue with restore? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Restore cancelled"
        return 0
    fi

    print_status "Uploading backup to VM..."

    # Upload backup file
    rsync -avz --progress \
        -e "ssh -p $REMOTE_PORT" \
        "$backup_file" \
        "$REMOTE_USER@$REMOTE_HOST:/tmp/"

    local backup_name
    backup_name=$(basename "$backup_file")

    print_status "Restoring backup on VM..."

    # Restore on remote VM
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" bash << EOF
set -e
echo "🔄 Restoring backup: $backup_name"

# Extract backup
cd /
tar -xzf "/tmp/$backup_name"

# Clean up uploaded file
rm "/tmp/$backup_name"

echo "✅ Backup restored successfully"
EOF

    print_success "Backup restored to VM"
}

# Main function
main() {
    local action="backup"
    local backup_file=""
    local keep_count=5

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-name)
                APP_NAME="$2"
                REMOTE_HOST="$APP_NAME.fly.dev"
                shift 2
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --action)
                action="$2"
                shift 2
                ;;
            --file)
                backup_file="$2"
                shift 2
                ;;
            --keep)
                keep_count="$2"
                shift 2
                ;;
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --app-name NAME     Fly.io app name (default: claude-dev-env)
  --backup-dir DIR    Local backup directory (default: ./backups)
  --action ACTION     Action to perform (backup, sync, restore, list, cleanup)
  --file FILE         Backup file for restore action
  --keep COUNT        Number of backups to keep for cleanup (default: 5)
  --help              Show this help message

Actions:
  backup              Create and download backup (default)
  sync                Sync entire workspace to local directory
  restore             Restore backup to VM (requires --file)
  list                List available backups
  cleanup             Remove old local backups

Examples:
  $0                                    # Create and download backup
  $0 --action sync                      # Sync workspace
  $0 --action restore --file backup.tar.gz  # Restore backup
  $0 --action list                      # List backups
  $0 --action cleanup --keep 3          # Keep only 3 most recent backups

Environment Variables:
  APP_NAME           Fly.io application name
  BACKUP_DIR         Local backup directory

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

    echo "💾 Fly.io Volume Backup Tool"
    echo "============================"
    echo "App: $APP_NAME"
    echo "Backup Dir: $BACKUP_DIR"
    echo "Action: $action"
    echo

    case $action in
        backup)
            check_prerequisites
            check_vm_status
            backup_name=$(create_remote_backup)
            download_backup "$backup_name"
            print_success "🎉 Backup completed successfully!"
            ;;
        sync)
            check_prerequisites
            check_vm_status
            sync_workspace
            print_success "🎉 Workspace sync completed!"
            ;;
        restore)
            if [[ -z "$backup_file" ]]; then
                print_error "Restore requires --file parameter"
                exit 1
            fi
            check_prerequisites
            check_vm_status
            restore_backup "$backup_file"
            print_success "🎉 Restore completed!"
            ;;
        list)
            echo "📋 Backup Inventory"
            echo "=================="
            list_remote_backups
            echo
            list_local_backups
            ;;
        cleanup)
            cleanup_backups "$keep_count"
            print_success "🎉 Cleanup completed!"
            ;;
        *)
            print_error "Unknown action: $action"
            print_status "Use --help for available actions"
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi