#!/bin/bash
# Backup critical workspace data

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

BACKUP_DATE=$(get_timestamp)
CRITICAL_DIRS="/workspace/projects /workspace/developer/.claude /workspace/.config"

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