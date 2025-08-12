#!/bin/bash
# fly-backup.sh - Backup and restore functions for Fly.io volumes
# This library provides functions for backup creation, transfer, and restoration

# Source common utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Only source if not already loaded (avoid circular dependencies)
[[ "${FLY_COMMON_SH_LOADED:-}" != "true" ]] && source "${LIB_DIR}/fly-common.sh"
[[ "${FLY_VM_SH_LOADED:-}" != "true" ]] && source "${LIB_DIR}/fly-vm.sh"

# Prevent multiple sourcing
if [[ "${FLY_BACKUP_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
FLY_BACKUP_SH_LOADED="true"

# Default backup directories and exclusions
DEFAULT_BACKUP_DIRS="/workspace/projects /workspace/.config /home/developer/.claude /workspace/scripts"
DEFAULT_EXCLUDE_PATTERNS=(
    "--exclude=/workspace/backups"
    "--exclude=/workspace/.cache"
    "--exclude=node_modules"
    "--exclude=.git/objects"
    "--exclude=*.log"
    "--exclude=__pycache__"
    "--exclude=*.tmp"
)

# Function to create backup filename
get_backup_filename() {
    local prefix="${1:-backup}"
    local app_name="${2:-unknown}"
    local timestamp
    timestamp=$(get_backup_timestamp)
    echo "${prefix}_${app_name}_${timestamp}.tar.gz"
}

# Function to create remote backup on VM
create_remote_backup() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"
    local backup_name="$4"
    local backup_dirs="${5:-$DEFAULT_BACKUP_DIRS}"

    print_status "Creating backup on remote VM..."

    # Create backup script
    local backup_script="
set -e
echo '🔄 Creating remote backup...'

# Define backup parameters
BACKUP_DIRS=\"$backup_dirs\"
BACKUP_FILE=\"/workspace/backups/$backup_name\"

# Create backups directory
mkdir -p /workspace/backups

# Create compressed backup with exclusions
tar $(printf '%s ' "${DEFAULT_EXCLUDE_PATTERNS[@]}") \\
    -czf \"\$BACKUP_FILE\" \$BACKUP_DIRS 2>/dev/null || {
    echo '⚠️ Some files may not be accessible, continuing...'
    tar --ignore-failed-read \\
        $(printf '%s ' "${DEFAULT_EXCLUDE_PATTERNS[@]}") \\
        -czf \"\$BACKUP_FILE\" \$BACKUP_DIRS
}

# Show backup info
echo '✅ Remote backup created: $backup_name'
ls -lh \"\$BACKUP_FILE\"

# Keep only last 5 remote backups to save space
find /workspace/backups -name \"backup_*.tar.gz\" -type f | sort | head -n -5 | xargs -r rm

echo '📊 Remaining backups:'
ls -lh /workspace/backups/backup_*.tar.gz 2>/dev/null || echo 'No backups found'
"

    execute_remote_script "$remote_host" "$remote_port" "$remote_user" "$backup_script"
    print_success "Remote backup created: $backup_name"
}

# Function to create suspend backup
create_suspend_backup() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"
    local app_name="${4:-unknown}"

    local backup_name
    backup_name=$(get_backup_filename "suspend_backup" "$app_name")

    print_status "Creating pre-suspend backup..."

    local critical_dirs="/workspace/projects /home/developer/.claude /workspace/.config"

    # Create lightweight suspend backup
    local suspend_script="
set -e
BACKUP_DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE=\"/workspace/backups/$backup_name\"
CRITICAL_DIRS=\"$critical_dirs\"

# Create backups directory
mkdir -p /workspace/backups

# Create lightweight backup (exclude large files)
echo '🔄 Creating suspend backup...'
tar $(printf '%s ' "${DEFAULT_EXCLUDE_PATTERNS[@]}") \\
    -czf \"\$BACKUP_FILE\" \$CRITICAL_DIRS 2>/dev/null || {
    echo '⚠️ Some files inaccessible, continuing...'
    tar --ignore-failed-read \\
        $(printf '%s ' "${DEFAULT_EXCLUDE_PATTERNS[@]}") \\
        -czf \"\$BACKUP_FILE\" \$CRITICAL_DIRS
}

# Keep only last 3 suspend backups
find /workspace/backups -name \"suspend_backup_*.tar.gz\" -type f | sort | head -n -3 | xargs -r rm

echo '✅ Suspend backup created: $backup_name'
ls -lh \"\$BACKUP_FILE\"
"

    execute_remote_script "$remote_host" "$remote_port" "$remote_user" "$suspend_script"
    print_success "Suspend backup created: $backup_name"
    echo "$backup_name"
}

# Function to download backup using rsync
download_backup() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"
    local backup_name="$4"
    local local_backup_dir="$5"

    local local_backup_path="$local_backup_dir/$backup_name"

    print_status "Downloading backup to local machine..."

    # Ensure local backup directory exists
    mkdir -p "$local_backup_dir"

    # Download using rsync for reliability
    if rsync -avz --progress \
        -e "ssh -p $remote_port" \
        "$remote_user@$remote_host:/workspace/backups/$backup_name" \
        "$local_backup_path"; then

        print_success "Backup downloaded: $local_backup_path"
        ls -lh "$local_backup_path"
        return 0
    else
        print_error "Failed to download backup"
        return 1
    fi
}

# Function to upload backup to VM
upload_backup() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"
    local local_backup_path="$4"

    if [[ ! -f "$local_backup_path" ]]; then
        print_error "Backup file not found: $local_backup_path"
        return 1
    fi

    print_status "Uploading backup to VM..."

    local backup_name
    backup_name=$(basename "$local_backup_path")

    # Upload backup file
    if rsync -avz --progress \
        -e "ssh -p $remote_port" \
        "$local_backup_path" \
        "$remote_user@$remote_host:/tmp/"; then

        print_success "Backup uploaded: $backup_name"
        echo "$backup_name"
        return 0
    else
        print_error "Failed to upload backup"
        return 1
    fi
}

# Function to extract backup on VM
extract_backup() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"
    local backup_name="$4"

    print_status "Extracting backup on VM..."

    local extract_script="
set -e
echo '🔄 Extracting backup: $backup_name'

# Change to root directory for extraction
cd /

# Extract backup (this will overwrite existing files)
tar -xzf \"/tmp/$backup_name\"

# Set correct permissions
chown -R developer:developer /workspace 2>/dev/null || true
chown -R developer:developer /home/developer/.claude 2>/dev/null || true

# Clean up uploaded file
rm \"/tmp/$backup_name\"

echo '✅ Backup extracted successfully'
echo '📁 Restored directories:'
echo '   /workspace/projects'
echo '   /workspace/.config'
echo '   /home/developer/.claude'
"

    execute_remote_script "$remote_host" "$remote_port" "$remote_user" "$extract_script"
    print_success "Backup extracted successfully"
}

# Function to sync entire workspace
sync_workspace() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"
    local local_sync_dir="$4"

    print_status "Syncing entire workspace..."

    mkdir -p "$local_sync_dir"

    # Build exclusion arguments for rsync
    local exclude_args=()
    for pattern in "/workspace/backups" "/workspace/.cache" "node_modules" ".git/objects" "*.log" "__pycache__"; do
        exclude_args+=("--exclude=$pattern")
    done

    # Sync workspace using rsync with exclusions
    if rsync -avz --progress \
        "${exclude_args[@]}" \
        -e "ssh -p $remote_port" \
        "$remote_user@$remote_host:/workspace/" \
        "$local_sync_dir/"; then

        print_success "Workspace synced to: $local_sync_dir"
        return 0
    else
        print_error "Failed to sync workspace"
        return 1
    fi
}

# Function to list remote backups
list_remote_backups() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"

    print_status "Remote backups:"
    execute_remote_command "$remote_host" "$remote_port" "$remote_user" \
        "ls -lh /workspace/backups/backup_*.tar.gz 2>/dev/null || echo 'No remote backups found'"
}

# Function to list local backups
list_local_backups() {
    local backup_dir="$1"

    print_status "Local backups:"
    ls -lh "$backup_dir"/backup_*.tar.gz 2>/dev/null || echo "No local backups found"
    echo

    if [[ -d "$backup_dir" ]]; then
        print_status "Local sync directories:"
        find "$backup_dir" -name "workspace_sync_*" -type d | sort
    fi
}

# Function to cleanup old backups
cleanup_local_backups() {
    local backup_dir="$1"
    local keep_count="${2:-5}"

    print_status "Cleaning up old local backups (keeping $keep_count)..."

    # Remove old local backup files
    if ls "$backup_dir"/backup_*.tar.gz >/dev/null 2>&1; then
        find "$backup_dir" -name "backup_*.tar.gz" -type f | sort | head -n -"$keep_count" | xargs -r rm
        print_success "Old backup files cleaned up"
    fi

    # Remove old sync directories (keep 3)
    if find "$backup_dir" -name "workspace_sync_*" -type d >/dev/null 2>&1; then
        find "$backup_dir" -name "workspace_sync_*" -type d | sort | head -n -3 | xargs -r rm -rf
        print_success "Old sync directories cleaned up"
    fi
}

# Function to verify backup contents
verify_backup() {
    local backup_path="$1"

    if [[ ! -f "$backup_path" ]]; then
        print_error "Backup file not found: $backup_path"
        return 1
    fi

    print_status "Verifying backup contents:"

    # Show backup file info
    ls -lh "$backup_path"
    echo

    # Show contents preview
    print_status "Backup contents preview:"
    tar -tzf "$backup_path" | head -15

    local total_files
    total_files=$(tar -tzf "$backup_path" | wc -l)
    echo "... ($total_files total files)"

    return 0
}

# Function to create pre-restore backup
create_pre_restore_backup() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"

    print_status "Creating pre-restore backup for safety..."

    local backup_name
    backup_name=$(get_backup_filename "pre_restore_backup" "safety")

    local backup_script="
set -e
BACKUP_DIRS=\"/workspace/projects /workspace/.config /home/developer/.claude\"
BACKUP_FILE=\"/workspace/backups/$backup_name\"

# Create backups directory
mkdir -p /workspace/backups

# Create backup
tar $(printf '%s ' "${DEFAULT_EXCLUDE_PATTERNS[@]}") \\
    -czf \"\$BACKUP_FILE\" \$BACKUP_DIRS 2>/dev/null || {
    tar --ignore-failed-read \\
        $(printf '%s ' "${DEFAULT_EXCLUDE_PATTERNS[@]}") \\
        -czf \"\$BACKUP_FILE\" \$BACKUP_DIRS
}

echo '✅ Pre-restore backup created: $backup_name'
ls -lh \"\$BACKUP_FILE\"
"

    execute_remote_script "$remote_host" "$remote_port" "$remote_user" "$backup_script"
    print_success "Pre-restore backup created: $backup_name"
    echo "$backup_name"
}

# Function to verify restoration
verify_restoration() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"

    print_status "Verifying restoration..."

    execute_remote_script "$remote_host" "$remote_port" "$remote_user" '
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
df -h /workspace | awk '\''NR==2 {print "   Used: " $3 " / " $2 " (" $5 ")"}'\''
'

    print_success "Verification completed"
}

# Export functions
export -f get_backup_filename create_remote_backup create_suspend_backup
export -f download_backup upload_backup extract_backup sync_workspace
export -f list_remote_backups list_local_backups cleanup_local_backups
export -f verify_backup create_pre_restore_backup verify_restoration