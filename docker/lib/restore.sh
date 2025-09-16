#!/bin/bash
# Restore from backup

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

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