#!/bin/bash
# vm-resume.sh - Resume suspended Fly.io VM
# This script runs on your LOCAL machine to resume VM from suspend

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
MAX_WAIT_TIME=120  # Maximum wait time in seconds

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

# Function to check current VM status (returns only state for parsing)
check_vm_status() {
    local machine_info
    if ! machine_info=$(flyctl machine list -a "$APP_NAME" --json 2>/dev/null); then
        print_error "Failed to get machine information"
        print_error "Check that app '$APP_NAME' exists and you're authenticated"
        exit 1
    fi

    # Check if we have valid JSON and at least one machine
    if ! echo "$machine_info" | jq -e '.[0]' >/dev/null 2>&1; then
        print_error "No machines found or invalid response"
        exit 1
    fi

    local machine_state
    machine_state=$(echo "$machine_info" | jq -r 'if .[0].state then .[0].state else "unknown" end' 2>/dev/null)
    machine_state=${machine_state:-"unknown"}
    
    echo "$machine_state"
}

# Function to get detailed VM information for status display
get_vm_details() {
    local machine_info
    if ! machine_info=$(flyctl machine list -a "$APP_NAME" --json 2>/dev/null); then
        return 1
    fi

    # Check if we have valid JSON and at least one machine
    if ! echo "$machine_info" | jq -e '.[0]' >/dev/null 2>&1; then
        return 1
    fi

    local machine_id machine_state machine_region

    # Extract values with better error handling
    machine_id=$(echo "$machine_info" | jq -r 'if .[0].id then .[0].id else "unknown" end' 2>/dev/null)
    machine_state=$(echo "$machine_info" | jq -r 'if .[0].state then .[0].state else "unknown" end' 2>/dev/null)
    machine_region=$(echo "$machine_info" | jq -r 'if .[0].region then .[0].region else "unknown" end' 2>/dev/null)

    # Ensure all variables have values
    machine_id=${machine_id:-"unknown"}
    machine_state=${machine_state:-"unknown"}
    machine_region=${machine_region:-"unknown"}

    # Return pipe-delimited format
    echo "${machine_id}|${machine_state}|${machine_region}"
}

# Function to start the VM
start_vm() {
    local machine_id="$1"

    print_status "Starting VM..."

    flyctl machine start "$machine_id" -a "$APP_NAME"

    print_success "VM start command sent"
}

# Function to wait for VM to be ready
wait_for_vm_ready() {
    print_status "Waiting for VM to be fully operational..."

    local start_time
    start_time=$(date +%s)
    local retries=0
    local max_retries=$((MAX_WAIT_TIME / 2))

    # First, wait for machine state to be 'started'
    while [[ $retries -lt $max_retries ]]; do
        local current_state
        current_state=$(flyctl machine list -a "$APP_NAME" --json | jq -r '.[0].state' 2>/dev/null || echo "unknown")

        if [[ "$current_state" == "started" ]]; then
            print_success "VM is in started state"
            break
        fi

        if [[ $retries -eq 0 ]]; then
            echo -n "Waiting for VM to start"
        fi
        echo -n "."
        sleep 2
        ((retries++))
    done
    echo

    if [[ $retries -eq $max_retries ]]; then
        print_error "VM failed to start within timeout"
        return 1
    fi

    # Then wait for SSH to be available
    print_status "Waiting for SSH service to be available..."
    retries=0

    while [[ $retries -lt $max_retries ]]; do
        if ssh -o ConnectTimeout=3 -o BatchMode=yes -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" exit 2>/dev/null; then
            local end_time
            end_time=$(date +%s)
            local duration=$((end_time - start_time))
            print_success "SSH is ready (took ${duration}s)"
            return 0
        fi

        if [[ $retries -eq 0 ]]; then
            echo -n "Waiting for SSH"
        fi
        echo -n "."
        sleep 2
        ((retries++))
    done
    echo

    print_error "SSH service failed to become available within timeout"
    return 1
}

# Function to verify VM functionality
verify_vm_functionality() {
    print_status "Verifying VM functionality..."

    # Test SSH connection and run basic commands
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" bash << 'EOF'
echo "🔍 VM Functionality Check:"
echo "=========================="

echo "✅ SSH connection: Working"

echo -n "✅ Workspace mount: "
if [[ -d /workspace ]]; then
    echo "OK ($(df -h /workspace | awk 'NR==2 {print $4}' | head -1) available)"
else
    echo "❌ Missing"
fi

echo -n "✅ Node.js: "
if command -v node >/dev/null 2>&1; then
    echo "$(node --version)"
else
    echo "❌ Not found"
fi

echo -n "✅ Claude Code: "
if command -v claude >/dev/null 2>&1; then
    echo "Available"
else
    echo "❌ Not found"
fi

echo -n "✅ Git: "
if command -v git >/dev/null 2>&1; then
    echo "$(git --version | head -1)"
else
    echo "❌ Not found"
fi

echo "✅ System uptime: $(uptime -p)"

echo -e "\n📁 Workspace structure:"
find /workspace -maxdepth 2 -type d 2>/dev/null | head -5 | sed 's/^/   /'
EOF

    print_success "VM functionality verified"
}

# Function to restore any suspended sessions
restore_sessions() {
    print_status "Checking for suspended sessions to restore..."

    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" bash << 'EOF'
# Check for tmux sessions
if command -v tmux >/dev/null 2>&1; then
    session_count=$(tmux list-sessions 2>/dev/null | wc -l || echo 0)
    if [[ $session_count -gt 0 ]]; then
        echo "🔄 Found $session_count tmux session(s):"
        tmux list-sessions 2>/dev/null | sed 's/^/   /'
        echo "   💡 Reconnect with: tmux attach"
    else
        echo "📱 No tmux sessions found"
    fi
else
    echo "📱 tmux not available"
fi

# Check for any restore scripts or suspend backups
if ls /workspace/backups/suspend_backup_*.tar.gz >/dev/null 2>&1; then
    echo "💾 Suspend backups available:"
    ls -1t /workspace/backups/suspend_backup_*.tar.gz | head -3 | sed 's/^/   /'
fi
EOF

    print_success "Session check completed"
}

# Function to show connection information
show_connection_info() {
    print_success "🔌 VM Ready for Connection!"
    echo
    print_status "Connection Options:"
    echo "  • SSH: ssh $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT"
    echo "  • VSCode Remote-SSH: Connect to configured host"
    echo "  • IntelliJ Gateway: Use existing SSH configuration"
    echo
    print_status "Quick Commands:"
    echo "  • Check status: ssh $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT 'uptime'"
    echo "  • Start Claude: ssh $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT 'cd /workspace && claude'"
    echo "  • View projects: ssh $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT 'ls -la /workspace/projects/'"
    echo
    print_status "💡 Tips:"
    echo "  • Use tmux for persistent sessions: tmux new-session -s work"
    echo "  • All work should be in /workspace (persistent across suspends)"
    echo "  • VM will auto-suspend after period of inactivity"
}

# Function to perform full resume workflow
full_resume() {
    local skip_verification="$1"

    # Get current VM status
    local current_state
    current_state=$(check_vm_status)
    
    # Get machine details for machine ID
    local vm_details
    if ! vm_details=$(get_vm_details); then
        print_error "Failed to get VM details"
        return 1
    fi
    
    local machine_id machine_region
    machine_id=$(echo "$vm_details" | cut -d'|' -f1)
    machine_region=$(echo "$vm_details" | cut -d'|' -f3)

    echo

    case "$current_state" in
        "started")
            print_success "VM is already running!"

            # Still verify SSH accessibility
            if ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" exit 2>/dev/null; then
                print_success "SSH is accessible"

                if [[ "$skip_verification" != "true" ]]; then
                    echo
                    restore_sessions
                fi

                echo
                show_connection_info
                return 0
            else
                print_warning "VM is started but SSH is not accessible"
                print_status "This may be normal if VM just started, waiting..."

                if wait_for_vm_ready; then
                    print_success "SSH is now accessible"
                else
                    print_error "SSH failed to become accessible"
                    return 1
                fi
            fi
            ;;
        "stopped")
            print_status "VM is suspended, resuming..."
            start_vm "$machine_id"

            if ! wait_for_vm_ready; then
                print_error "Failed to resume VM properly"
                return 1
            fi
            ;;
        *)
            print_warning "VM is in '$current_state' state"
            print_status "Attempting to start anyway..."
            start_vm "$machine_id"

            if ! wait_for_vm_ready; then
                print_error "Failed to start VM properly"
                return 1
            fi
            ;;
    esac

    # Verify functionality unless skipped
    if [[ "$skip_verification" != "true" ]]; then
        echo
        verify_vm_functionality
        echo
        restore_sessions
    fi

    echo
    show_connection_info

    print_success "🎉 VM resumed successfully!"
}

# Function to show current status
show_status() {
    local current_state
    current_state=$(check_vm_status)

    echo
    print_status "📊 Current Status:"

    case "$current_state" in
        "started")
            echo "  • VM Status: ✅ RUNNING"
            echo "  • Compute Costs: 💸 ACTIVE"

            if ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" exit 2>/dev/null; then
                echo "  • SSH Access: ✅ AVAILABLE"

                # Get additional info
                local uptime
                local load
                uptime=$(ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "uptime -p" 2>/dev/null || echo "unknown")
                load=$(ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "uptime | awk -F'load average:' '{print \$2}'" 2>/dev/null || echo "unknown")

                echo "  • Uptime: $uptime"
                echo "  • Load: $load"
            else
                echo "  • SSH Access: ⚠️  STARTING UP"
            fi
            ;;
        "stopped")
            echo "  • VM Status: ⏸️  SUSPENDED"
            echo "  • Compute Costs: ✅ STOPPED"
            echo "  • SSH Access: ❌ UNAVAILABLE"
            echo "  • Resume: Run this script or connect via SSH/IDE"
            ;;
        *)
            echo "  • VM Status: ❓ $current_state"
            echo "  • Compute Costs: ❓ UNKNOWN"
            echo "  • SSH Access: ❓ UNKNOWN"
            ;;
    esac

    # Show connection info if running
    if [[ "$current_state" == "started" ]]; then
        echo
        show_connection_info
    fi
}

# Main function
main() {
    local action="resume"
    local skip_verification="false"

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
            --skip-verification)
                skip_verification="true"
                shift
                ;;
            --timeout)
                MAX_WAIT_TIME="$2"
                shift 2
                ;;
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --app-name NAME       Fly.io app name (default: claude-dev-env)
  --action ACTION       Action to perform (resume, status)
  --skip-verification   Skip functionality verification
  --timeout SECONDS     Maximum wait time for VM to be ready (default: 120)
  --help                Show this help message

Actions:
  resume                Resume suspended VM (default)
  status                Show current VM status

Examples:
  $0                              # Resume VM with full verification
  $0 --skip-verification          # Quick resume
  $0 --action status              # Show status only
  $0 --timeout 60                 # Resume with 60s timeout

Environment Variables:
  APP_NAME              Fly.io application name

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

    echo "▶️  Fly.io VM Resume Tool"
    echo "========================"
    echo "App: $APP_NAME"
    echo "Action: $action"
    echo "Max Wait: ${MAX_WAIT_TIME}s"
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
        resume)
            full_resume "$skip_verification"
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