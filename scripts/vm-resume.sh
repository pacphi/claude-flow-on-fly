#!/bin/bash
# vm-resume.sh - Resume suspended Fly.io VM
# This script runs on your LOCAL machine to resume VM from suspend

set -e

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/fly-common.sh"
source "$SCRIPT_DIR/lib/fly-vm.sh"

# Configuration
APP_NAME="${APP_NAME:-${DEFAULT_APP_NAME:-claude-dev-env}}"
REMOTE_USER="${DEFAULT_REMOTE_USER:-developer}"
REMOTE_HOST="$APP_NAME.fly.dev"
REMOTE_PORT="${DEFAULT_REMOTE_PORT:-10022}"
MAX_WAIT_TIME=120  # Maximum wait time in seconds

# Function to check current VM status
get_vm_status() {
    check_vm_status "$APP_NAME"
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
start_machine() {
    local machine_id="$1"
    start_vm "$APP_NAME" "$machine_id"
}

# Function to wait for VM to be ready
wait_for_ready() {
    wait_for_vm_ready "$APP_NAME" "$REMOTE_HOST" "$REMOTE_PORT" "$REMOTE_USER" "$MAX_WAIT_TIME"
}

# Function to verify VM functionality
verify_functionality() {
    verify_vm_functionality "$REMOTE_HOST" "$REMOTE_PORT" "$REMOTE_USER"
}

# Function to restore suspended sessions
restore_vm_sessions() {
    restore_sessions "$REMOTE_HOST" "$REMOTE_PORT" "$REMOTE_USER"
}

# Function to show connection information
show_connection_details() {
    show_connection_info "$APP_NAME" "$REMOTE_HOST" "$REMOTE_PORT" "$REMOTE_USER"
}

# Function to perform full resume workflow
full_resume() {
    local skip_verification="$1"

    # Get current VM status
    local current_state
    current_state=$(get_vm_status)

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
                    restore_vm_sessions
                fi

                echo
                show_connection_details
                return 0
            else
                print_warning "VM is started but SSH is not accessible"
                print_status "This may be normal if VM just started, waiting..."

                if wait_for_ready; then
                    print_success "SSH is now accessible"
                else
                    print_error "SSH failed to become accessible"
                    return 1
                fi
            fi
            ;;
        "stopped"|"suspended")
            print_status "VM is suspended, resuming..."
            start_machine "$machine_id"

            if ! wait_for_ready; then
                print_error "Failed to resume VM properly"
                return 1
            fi
            ;;
        *)
            print_warning "VM is in '$current_state' state"
            print_status "Attempting to start anyway..."
            start_machine "$machine_id"

            if ! wait_for_ready; then
                print_error "Failed to start VM properly"
                return 1
            fi
            ;;
    esac

    # Verify functionality unless skipped
    if [[ "$skip_verification" != "true" ]]; then
        echo
        verify_functionality
        echo
        restore_vm_sessions
    fi

    echo
    show_connection_details

    print_success "🎉 VM resumed successfully!"
}

# Function to show current status
show_status() {
    local current_state
    current_state=$(get_vm_status)

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
        "stopped"|"suspended")
            echo "  • VM Status: ⏸️  SUSPENDED"
            echo "  • Compute Costs: ✅ STOPPED ($0/hour)"
            echo "  • SSH Access: ❌ UNAVAILABLE"
            echo "  • Resume: Run this script or connect via SSH/IDE"
            echo "  • Auto-Resume: VM will start automatically on SSH connection"
            ;;
        *)
            echo "  • VM Status: ❓ $current_state"
            echo "  • Compute Costs: ❓ UNKNOWN"
            echo "  • SSH Access: ❓ UNKNOWN"
            echo "  • Action: Try running this script to resume"
            ;;
    esac

    # Show connection info if running
    if [[ "$current_state" == "started" ]]; then
        echo
        show_connection_details
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
    check_prerequisites "jq"

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