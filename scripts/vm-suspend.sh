#!/bin/bash
# vm-suspend.sh - Suspend Fly.io VM for cost optimization
# This script runs on your LOCAL machine to manage VM lifecycle

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_NAME="${APP_NAME:-claude-dev-env}"
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

# Function to check current VM status
check_vm_status() {
    print_status "Checking VM status..."

    local machine_info
    if ! machine_info=$(flyctl machine list -a "$APP_NAME" --json 2>/dev/null); then
        print_error "Failed to get machine information"
        print_error "Check that app '$APP_NAME' exists and you're authenticated"
        exit 1
    fi

    local machine_id
    local machine_state
    local machine_region
    local machine_size

    machine_id=$(echo "$machine_info" | jq -r '.[0].id')
    machine_state=$(echo "$machine_info" | jq -r '.[0].state')
    machine_region=$(echo "$machine_info" | jq -r '.[0].region')
    machine_size=$(echo "$machine_info" | jq -r '.[0].config.size')

    echo "Machine ID: $machine_id"
    echo "State: $machine_state"
    echo "Region: $machine_region"
    echo "Size: $machine_size"

    echo "$machine_state"
}

# Function to gracefully shutdown active sessions
graceful_shutdown() {
    print_status "Performing graceful shutdown..."

    # Check if SSH is accessible
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" exit 2>/dev/null; then
        print_warning "SSH not accessible, skipping graceful shutdown"
        return 0
    fi

    # Send shutdown commands to VM
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" bash << 'EOF'
echo "🔄 Preparing for shutdown..."

# Save any tmux sessions
if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    echo "💾 Saving tmux sessions..."
    for session in $(tmux list-sessions -F "#{session_name}"); do
        tmux send-keys -t "$session" C-s 2>/dev/null || true
    done
fi

# Save any vim sessions
if pgrep vim >/dev/null 2>&1; then
    echo "💾 Saving vim sessions..."
    pkill -USR1 vim 2>/dev/null || true
    sleep 1
fi

# Sync filesystem
echo "💾 Syncing filesystem..."
sync

# Stop any running development servers gracefully
if pgrep -f "npm.*start\|npm.*dev\|node.*server" >/dev/null 2>&1; then
    echo "🛑 Stopping development servers..."
    pkill -TERM -f "npm.*start\|npm.*dev\|node.*server" 2>/dev/null || true
    sleep 2
fi

echo "✅ Graceful shutdown preparation complete"
EOF

    print_success "Graceful shutdown completed"
}

# Function to create pre-suspend backup
create_suspend_backup() {
    print_status "Creating pre-suspend backup..."

    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" bash << 'EOF'
set -e

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="/workspace/backups/suspend_backup_$BACKUP_DATE.tar.gz"
CRITICAL_DIRS="/workspace/projects /home/developer/.claude /workspace/.config"

# Create backups directory
mkdir -p /workspace/backups

# Create lightweight backup (exclude large files)
echo "🔄 Creating suspend backup..."
tar --exclude='/workspace/backups' \
    --exclude='/workspace/.cache' \
    --exclude='node_modules' \
    --exclude='.git/objects' \
    --exclude='*.log' \
    --exclude='__pycache__' \
    --exclude='*.tmp' \
    -czf "$BACKUP_FILE" $CRITICAL_DIRS 2>/dev/null || {
    echo "⚠️ Some files inaccessible, continuing..."
    tar --ignore-failed-read \
        --exclude='/workspace/backups' \
        --exclude='/workspace/.cache' \
        --exclude='node_modules' \
        --exclude='.git/objects' \
        --exclude='*.log' \
        --exclude='__pycache__' \
        --exclude='*.tmp' \
        -czf "$BACKUP_FILE" $CRITICAL_DIRS
}

# Keep only last 3 suspend backups
find /workspace/backups -name "suspend_backup_*.tar.gz" -type f | sort | head -n -3 | xargs -r rm

echo "✅ Suspend backup created: suspend_backup_$BACKUP_DATE.tar.gz"
ls -lh "$BACKUP_FILE"
EOF

    print_success "Pre-suspend backup created"
}

# Function to suspend the VM
suspend_vm() {
    local machine_id="$1"

    print_status "Suspending VM..."

    # Use fly machine stop to suspend
    flyctl machine stop "$machine_id" -a "$APP_NAME"

    print_success "VM suspended"
}

# Function to show cost savings
show_cost_info() {
    print_status "💰 Cost Optimization Information:"
    echo "  • VM compute costs: STOPPED ✅"
    echo "  • Volume storage costs: CONTINUE (persistent data)"
    echo "  • Estimated savings: ~\$5-10/month in compute costs"
    echo "  • Resume time: ~30-60 seconds"
    echo
    print_warning "💡 Volume storage costs (~\$1.50/month for 10GB) continue even when suspended"
}

# Function to show resume instructions
show_resume_info() {
    print_success "📋 Resume Instructions:"
    echo "  • Manual resume: flyctl machine start <machine-id> -a $APP_NAME"
    echo "  • Automatic resume: SSH or HTTP request will start the VM"
    echo "  • Resume script: ./scripts/vm-resume.sh"
    echo
    print_status "🔌 Connection Info (for resume):"
    echo "  • SSH: ssh $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT"
    echo "  • App URL: https://$APP_NAME.fly.dev"
}

# Function to perform full suspend workflow
full_suspend() {
    local skip_backup="$1"
    local force_suspend="$2"

    # Get current VM status
    local current_state
    current_state=$(check_vm_status)

    echo

    if [[ "$current_state" != "started" ]]; then
        print_warning "VM is already in '$current_state' state"

        if [[ "$current_state" == "stopped" ]]; then
            print_success "VM is already suspended"
            show_cost_info
            return 0
        fi

        if [[ "$force_suspend" != "true" ]]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_status "Suspend cancelled"
                return 0
            fi
        fi
    fi

    # Confirm suspend operation
    if [[ "$force_suspend" != "true" ]]; then
        print_warning "This will suspend the VM and stop compute charges"
        print_warning "Active SSH sessions will be disconnected"
        echo
        read -p "Continue with suspend? (y/N): " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Suspend operation cancelled"
            return 0
        fi
    fi

    # Get machine ID
    local machine_id
    machine_id=$(flyctl machine list -a "$APP_NAME" --json | jq -r '.[0].id')

    # Perform graceful shutdown if VM is accessible
    if [[ "$current_state" == "started" ]]; then
        graceful_shutdown

        # Create backup if not skipped
        if [[ "$skip_backup" != "true" ]]; then
            create_suspend_backup
        fi

        # Brief pause to ensure operations complete
        sleep 2
    fi

    # Suspend the VM
    suspend_vm "$machine_id"

    echo
    show_cost_info
    echo
    show_resume_info

    print_success "🎉 VM suspended successfully!"
}

# Function to show status without suspending
show_status() {
    local current_state
    current_state=$(check_vm_status)

    echo
    print_status "📊 Current Status Summary:"

    case "$current_state" in
        "started")
            echo "  • VM Status: ✅ RUNNING"
            echo "  • Compute Costs: 💸 ACTIVE (~\$0.0067/hour)"
            echo "  • SSH Access: 🔌 AVAILABLE"
            ;;
        "stopped")
            echo "  • VM Status: ⏸️  SUSPENDED"
            echo "  • Compute Costs: ✅ STOPPED"
            echo "  • SSH Access: ❌ UNAVAILABLE"
            ;;
        *)
            echo "  • VM Status: ❓ $current_state"
            echo "  • Compute Costs: ❓ UNKNOWN"
            echo "  • SSH Access: ❓ UNKNOWN"
            ;;
    esac

    # Show volume info
    local volume_info
    if volume_info=$(flyctl volumes list -a "$APP_NAME" --json 2>/dev/null); then
        local volume_size
        volume_size=$(echo "$volume_info" | jq -r '.[0].size_gb')
        local volume_cost
        volume_cost=$(echo "scale=2; $volume_size * 0.15" | bc 2>/dev/null || echo "~\$1.50")

        echo "  • Volume Size: ${volume_size}GB"
        echo "  • Volume Cost: \$${volume_cost}/month (persistent)"
    fi

    echo
    show_resume_info
}

# Main function
main() {
    local action="suspend"
    local skip_backup="false"
    local force_suspend="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-name)
                APP_NAME="$2"
                REMOTE_HOST="$APP_NAME.fly.dev"
                shift 2
                ;;
            --action)
                action="$2"
                shift 2
                ;;
            --skip-backup)
                skip_backup="true"
                shift
                ;;
            --force)
                force_suspend="true"
                shift
                ;;
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --app-name NAME     Fly.io app name (default: claude-dev-env)
  --action ACTION     Action to perform (suspend, status)
  --skip-backup       Skip creating pre-suspend backup
  --force             Skip confirmation prompts
  --help              Show this help message

Actions:
  suspend             Suspend the VM to save costs (default)
  status              Show current VM status without suspending

Examples:
  $0                              # Interactive suspend
  $0 --force --skip-backup        # Quick suspend without backup
  $0 --action status              # Show status only
  $0 --app-name my-dev            # Suspend specific app

Environment Variables:
  APP_NAME            Fly.io application name

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

    echo "⏸️  Fly.io VM Suspend Tool"
    echo "=========================="
    echo "App: $APP_NAME"
    echo "Action: $action"
    echo

    # Check prerequisites
    if ! command -v flyctl >/dev/null 2>&1; then
        print_error "flyctl not found. Please install Fly.io CLI."
        exit 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        print_error "jq not found. Please install jq for JSON processing."
        exit 1
    fi

    case "$action" in
        suspend)
            full_suspend "$skip_backup" "$force_suspend"
            ;;
        status)
            show_status
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