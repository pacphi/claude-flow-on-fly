#!/bin/bash
# volume-restore.sh - Restore Fly.io volume data from backup
# This script runs on your LOCAL machine to restore VM data

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

# Function to list available backups
list_available_backups() {
    print_status "Available local backups:"

    local backups=()
    if ls "$BACKUP_DIR"/backup_*.tar.gz >/dev/null 2>&1; then
        while IFS= read -r -d '' backup; do
            backups+=("$(basename "$backup")")
        done < <(find "$BACKUP_DIR" -name "backup_*.tar.gz" -type f -print0 | sort -z)
    fi

    if [[ ${#backups[@]} -eq 0 ]]; then
        print_warning "No local backups found in $BACKUP_DIR"
        return 1
    fi

    for i in "${!backups[@]}"; do
        echo "  $((i+1)). ${backups[i]}"
        ls -lh "$BACKUP_DIR/${backups[i]}" | awk '{print "     Size: " $5 ", Modified: " $6 " " $7 " " $8}'
    done

    echo "${backups[@]}"
}

# Function to select backup interactively
select_backup() {
    local backups_string="$1"
    IFS=' ' read -ra backups <<< "$backups_string"

    if [[ ${#backups[@]} -eq 1 ]]; then
        echo "${backups[0]}"
        return 0
    fi

    while true; do
        read -p "Select backup number (1-${#backups[@]}): " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#backups[@]} ]]; then
            echo "${backups[$((selection-1))]}"
            return 0
        else
            print_error "Invalid selection. Please enter a number between 1 and ${#backups[@]}"
        fi
    done
}

# Function to check VM status and start if needed
ensure_vm_running() {
    print_status "Checking VM status..."

    local machine_status
    machine_status=$(flyctl machine list -a "$APP_NAME" --json | jq -r '.[0].state' 2>/dev/null || echo "unknown")

    if [[ "$machine_status" != "started" ]]; then
        print_warning "VM is not running (status: $machine_status)"
        print_status "Starting VM for restore operation..."

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
    fi

    print_success "VM is running and accessible"
}

# Function to create current backup before restore
create_pre_restore_backup() {
    print_status "Creating pre-restore backup for safety..."

    local backup_date
    backup_date=$(date +%Y%m%d_%H%M%S)
    local backup_name="pre_restore_backup_${backup_date}.tar.gz"

    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" bash << EOF
set -e
BACKUP_DIRS="/workspace/projects /workspace/.config /home/developer/.claude"
BACKUP_FILE="/workspace/backups/$backup_name"

# Create backups directory
mkdir -p /workspace/backups

# Create backup
tar --exclude='/workspace/backups' \\
    --exclude='/workspace/.cache' \\
    --exclude='node_modules' \\
    --exclude='.git/objects' \\
    -czf "\$BACKUP_FILE" \$BACKUP_DIRS 2>/dev/null || {
    tar --ignore-failed-read \\
        --exclude='/workspace/backups' \\
        --exclude='/workspace/.cache' \\
        --exclude='node_modules' \\
        --exclude='.git/objects' \\
        -czf "\$BACKUP_FILE" \$BACKUP_DIRS
}

echo "✅ Pre-restore backup created: $backup_name"
ls -lh "\$BACKUP_FILE"
EOF

    print_success "Pre-restore backup created: $backup_name"
}

# Function to restore backup to VM
restore_backup_to_vm() {
    local backup_file="$1"
    local backup_path="$BACKUP_DIR/$backup_file"

    if [[ ! -f "$backup_path" ]]; then
        print_error "Backup file not found: $backup_path"
        exit 1
    fi

    print_status "Uploading backup to VM..."

    # Upload backup file
    rsync -avz --progress \
        -e "ssh -p $REMOTE_PORT" \
        "$backup_path" \
        "$REMOTE_USER@$REMOTE_HOST:/tmp/"

    print_success "Backup uploaded to VM"

    print_status "Extracting backup on VM..."

    # Extract backup on remote VM
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" bash << EOF
set -e
echo "🔄 Extracting backup: $backup_file"

# Change to root directory for extraction
cd /

# Extract backup (this will overwrite existing files)
tar -xzf "/tmp/$backup_file"

# Set correct permissions
chown -R developer:developer /workspace 2>/dev/null || true
chown -R developer:developer /home/developer/.claude 2>/dev/null || true

# Clean up uploaded file
rm "/tmp/$backup_file"

echo "✅ Backup extracted successfully"
echo "📁 Restored directories:"
echo "   /workspace/projects"
echo "   /workspace/.config"
echo "   /home/developer/.claude"
EOF

    print_success "Backup restored successfully"
}

# Function to verify restoration
verify_restoration() {
    print_status "Verifying restoration..."

    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" bash << 'EOF'
echo "📊 Restoration Verification:"
echo "============================"

echo "📁 Workspace structure:"
find /workspace -maxdepth 2 -type d 2>/dev/null | head -10

echo -e "\n🔧 Claude configuration:"
if [[ -f /home/developer/.claude/CLAUDE.md ]]; then
    echo "   ✅ Global CLAUDE.md found"
else
    echo "   ❌ Global CLAUDE.md missing"
fi

if [[ -f /home/developer/.claude/settings.json ]]; then
    echo "   ✅ Claude settings found"
else
    echo "   ❌ Claude settings missing"
fi

echo -e "\n📦 Projects:"
project_count=$(find /workspace/projects -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
echo "   Found $project_count project directories"

echo -e "\n💾 Disk usage:"
df -h /workspace | awk 'NR==2 {print "   Used: " $3 " / " $2 " (" $5 ")"}'
EOF

    print_success "Verification completed"
}

# Function to perform full restore workflow
full_restore() {
    local backup_file="$1"
    local skip_pre_backup="$2"

    print_warning "⚠️  RESTORE OPERATION WARNING ⚠️"
    echo "This operation will:"
    echo "  • Overwrite current data on the VM"
    echo "  • Replace projects, configurations, and Claude settings"
    echo "  • Cannot be easily undone"
    echo

    if [[ "$skip_pre_backup" != "true" ]]; then
        echo "A pre-restore backup will be created for safety."
        echo
    fi

    read -p "Continue with restore? (y/N): " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Restore operation cancelled"
        return 0
    fi

    ensure_vm_running

    if [[ "$skip_pre_backup" != "true" ]]; then
        create_pre_restore_backup
        echo
    fi

    restore_backup_to_vm "$backup_file"
    echo

    verify_restoration
    echo

    print_success "🎉 Restore operation completed successfully!"
    print_status "💡 Next steps:"
    echo "   1. Connect to VM: ssh developer@$REMOTE_HOST -p $REMOTE_PORT"
    echo "   2. Verify your projects and configurations"
    echo "   3. Re-authenticate Claude if needed: claude"
}

# Function to restore from Fly.io volume snapshot
restore_from_snapshot() {
    print_status "Available volume snapshots:"

    # List volume snapshots
    local volume_id
    volume_id=$(flyctl volumes list -a "$APP_NAME" --json | jq -r '.[0].id')

    flyctl volumes snapshots list "$volume_id" -a "$APP_NAME"

    echo
    read -p "Enter snapshot ID to restore from: " snapshot_id

    if [[ -z "$snapshot_id" ]]; then
        print_error "No snapshot ID provided"
        return 1
    fi

    print_warning "This will restore the entire volume to the snapshot state"
    read -p "Continue? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Restoring from snapshot $snapshot_id..."
        flyctl volumes restore "$volume_id" "$snapshot_id" -a "$APP_NAME"
        print_success "Volume restored from snapshot"
    else
        print_status "Snapshot restore cancelled"
    fi
}

# Main function
main() {
    local backup_file=""
    local skip_pre_backup="false"
    local restore_type="backup"

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
            --file)
                backup_file="$2"
                shift 2
                ;;
            --skip-pre-backup)
                skip_pre_backup="true"
                shift
                ;;
            --from-snapshot)
                restore_type="snapshot"
                shift
                ;;
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --app-name NAME        Fly.io app name (default: claude-dev-env)
  --backup-dir DIR       Local backup directory (default: ./backups)
  --file FILE            Specific backup file to restore
  --skip-pre-backup      Skip creating pre-restore backup
  --from-snapshot        Restore from Fly.io volume snapshot
  --help                 Show this help message

Examples:
  $0                                   # Interactive restore from local backup
  $0 --file backup_20250104_120000.tar.gz  # Restore specific backup
  $0 --from-snapshot                   # Restore from volume snapshot
  $0 --skip-pre-backup --file backup.tar.gz  # Skip safety backup

Environment Variables:
  APP_NAME               Fly.io application name
  BACKUP_DIR             Local backup directory

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

    echo "🔄 Fly.io Volume Restore Tool"
    echo "============================="
    echo "App: $APP_NAME"
    echo "Backup Dir: $BACKUP_DIR"
    echo "Restore Type: $restore_type"
    echo

    # Check prerequisites
    if ! command -v flyctl >/dev/null 2>&1; then
        print_error "flyctl not found. Please install Fly.io CLI."
        exit 1
    fi

    if [[ "$restore_type" == "snapshot" ]]; then
        restore_from_snapshot
        return 0
    fi

    # Handle backup file selection
    if [[ -z "$backup_file" ]]; then
        if ! available_backups=$(list_available_backups); then
            print_error "No backups available for restore"
            exit 1
        fi

        echo
        backup_file=$(select_backup "$available_backups")
    fi

    print_status "Selected backup: $backup_file"

    # Show backup details
    if [[ -f "$BACKUP_DIR/$backup_file" ]]; then
        echo "Backup details:"
        ls -lh "$BACKUP_DIR/$backup_file"

        # Show contents preview
        echo -e "\nBackup contents preview:"
        tar -tzf "$BACKUP_DIR/$backup_file" | head -10
        echo "..."
    else
        print_error "Backup file not found: $BACKUP_DIR/$backup_file"
        exit 1
    fi

    echo
    full_restore "$backup_file" "$skip_pre_backup"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi