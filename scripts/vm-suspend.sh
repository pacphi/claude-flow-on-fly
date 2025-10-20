#!/bin/bash
# vm-suspend.sh - Suspend Fly.io VM for cost optimization
# This script runs on your LOCAL machine to manage VM lifecycle

set -e

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/fly-common.sh"
source "$SCRIPT_DIR/lib/fly-vm.sh"
source "$SCRIPT_DIR/lib/fly-backup.sh"

# Configuration
APP_NAME="${APP_NAME:-${DEFAULT_APP_NAME:-sindri-dev-env}}"
REMOTE_USER="${DEFAULT_REMOTE_USER:-developer}"
REMOTE_HOST="$APP_NAME.fly.dev"
REMOTE_PORT="${DEFAULT_REMOTE_PORT:-10022}"

# Function to check current VM status
get_vm_state() {
    check_vm_status "$APP_NAME"
}

# Function to get full VM information
get_vm_info() {
    get_machine_info "$APP_NAME"
}

# Function to get volume information
get_volume_data() {
    get_volume_info "$APP_NAME"
}

# Function to gracefully shutdown active sessions
shutdown_gracefully() {
    graceful_shutdown "$REMOTE_HOST" "$REMOTE_PORT" "$REMOTE_USER"
}

# Function to create pre-suspend backup
create_backup() {
    create_suspend_backup "$REMOTE_HOST" "$REMOTE_PORT" "$REMOTE_USER" "$APP_NAME"
}

# Function to suspend the VM
suspend_vm() {
    local machine_id="$1"
    stop_vm "$APP_NAME" "$machine_id"
}

# Function to show cost savings
show_cost_info() {
    print_status "💰 Cost Optimization Information:"
    echo "  • VM compute costs: STOPPED ✅"
    echo "  • Volume storage costs: CONTINUE (persistent data)"
    echo "  • Estimated savings: ~\$5-10/month in compute costs"
    echo "  • Resume time: ~30-60 seconds"
    echo
    print_warning "💡 Volume storage costs (~\$4.50/month for 30GB) continue even when suspended"
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
    current_state=$(get_vm_state)

    echo

    if [[ "$current_state" != "started" ]]; then
        print_warning "VM is already in '$current_state' state"

        if [[ "$current_state" == "stopped" || "$current_state" == "suspended" ]]; then
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

    # Get machine ID from VM info
    local machine_id
    local vm_info
    if ! vm_info=$(get_vm_info); then
        print_error "Failed to get VM information for machine ID"
        return 1
    fi
    machine_id=$(echo "$vm_info" | cut -d'|' -f1)

    # Perform graceful shutdown if VM is accessible
    if [[ "$current_state" == "started" ]]; then
        shutdown_gracefully

        # Create backup if not skipped
        if [[ "$skip_backup" != "true" ]]; then
            create_backup
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
    print_status "Checking VM status..."

    local vm_info
    if ! vm_info=$(get_vm_info); then
        return 1
    fi

    local volume_info
    if ! volume_info=$(get_volume_data); then
        return 1
    fi

    # Parse VM info (pipe-delimited) with safer parsing
    local machine_id machine_name machine_state machine_region cpu_kind cpus memory_mb machine_created
    if [[ "$vm_info" =~ ^([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|(.*)$ ]]; then
        machine_id="${BASH_REMATCH[1]}"
        machine_name="${BASH_REMATCH[2]}"
        machine_state="${BASH_REMATCH[3]}"
        machine_region="${BASH_REMATCH[4]}"
        cpu_kind="${BASH_REMATCH[5]}"
        cpus="${BASH_REMATCH[6]}"
        memory_mb="${BASH_REMATCH[7]}"
        machine_created="${BASH_REMATCH[8]}"
    else
        # Fallback parsing using cut
        machine_id=$(echo "$vm_info" | cut -d'|' -f1)
        machine_name=$(echo "$vm_info" | cut -d'|' -f2)
        machine_state=$(echo "$vm_info" | cut -d'|' -f3)
        machine_region=$(echo "$vm_info" | cut -d'|' -f4)
        cpu_kind=$(echo "$vm_info" | cut -d'|' -f5)
        cpus=$(echo "$vm_info" | cut -d'|' -f6)
        memory_mb=$(echo "$vm_info" | cut -d'|' -f7)
        machine_created=$(echo "$vm_info" | cut -d'|' -f8)
    fi

    # Ensure all VM variables have values
    machine_id=${machine_id:-"unknown"}
    machine_name=${machine_name:-"unknown"}
    machine_state=${machine_state:-"unknown"}
    machine_region=${machine_region:-"unknown"}
    cpu_kind=${cpu_kind:-"shared"}
    cpus=${cpus:-"1"}
    memory_mb=${memory_mb:-"256"}

    # Parse volume info (pipe-delimited) with safer parsing
    local volume_id volume_name volume_size volume_region volume_created
    if [[ "$volume_info" =~ ^([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|(.*)$ ]]; then
        volume_id="${BASH_REMATCH[1]}"
        volume_name="${BASH_REMATCH[2]}"
        volume_size="${BASH_REMATCH[3]}"
        volume_region="${BASH_REMATCH[4]}"
        volume_created="${BASH_REMATCH[5]}"
    else
        # Fallback parsing using cut
        volume_id=$(echo "$volume_info" | cut -d'|' -f1)
        volume_name=$(echo "$volume_info" | cut -d'|' -f2)
        volume_size=$(echo "$volume_info" | cut -d'|' -f3)
        volume_region=$(echo "$volume_info" | cut -d'|' -f4)
        volume_created=$(echo "$volume_info" | cut -d'|' -f5)
    fi

    # Ensure all volume variables have values
    volume_id=${volume_id:-"unknown"}
    volume_name=${volume_name:-"unknown"}
    volume_size=${volume_size:-"10"}
    volume_region=${volume_region:-"unknown"}

    # Format VM size display
    local vm_size_display
    if [[ "$cpu_kind" == "performance" ]]; then
        vm_size_display="Performance ${cpus}vCPU / ${memory_mb}MB"
    else
        vm_size_display="Shared ${cpus}vCPU / ${memory_mb}MB"
    fi

    echo
    print_status "📊 Current Status Summary:"

    case "$machine_state" in
        "started")
            echo "  • VM Status: ✅ RUNNING"
            echo "  • Compute Costs: 💸 ACTIVE (~\$0.0067/hour)"
            echo "  • SSH Access: 🔌 AVAILABLE"
            ;;
        "stopped"|"suspended")
            echo "  • VM Status: ⏸️  SUSPENDED"
            echo "  • Compute Costs: ✅ STOPPED"
            echo "  • SSH Access: ❌ UNAVAILABLE"
            ;;
        *)
            echo "  • VM Status: ❓ $machine_state"
            echo "  • Compute Costs: ❓ UNKNOWN"
            echo "  • SSH Access: ❓ UNKNOWN"
            ;;
    esac

    # Show VM and volume details
    echo "  • VM Size: $vm_size_display"
    echo "  • VM Region: $machine_region"
    echo "  • Volume Size: ${volume_size}GB"

    # Calculate volume cost
    local volume_cost
    volume_cost=$(echo "scale=2; $volume_size * 0.15" | bc 2>/dev/null || echo "1.50")
    echo "  • Volume Cost: \$${volume_cost}/month (persistent)"

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
  --app-name NAME     Fly.io app name (default: sindri-dev-env)
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
    check_prerequisites "jq"

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