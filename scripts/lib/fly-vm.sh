#!/bin/bash
# fly-vm.sh - VM management functions for Fly.io scripts
# This library provides functions for VM control, SSH connectivity, and remote operations

# Source common utilities
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ "${FLY_COMMON_SH_LOADED:-}" != "true" ]] && source "${LIB_DIR}/fly-common.sh"

# Prevent multiple sourcing
if [[ "${FLY_VM_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
FLY_VM_SH_LOADED="true"

# Function to check current VM status (returns only state)
check_vm_status() {
    local app_name="$1"
    local machine_info

    if ! machine_info=$(get_machine_info "$app_name"); then
        return 1
    fi

    parse_machine_info "$machine_info" "state"
}

# Function to start VM
start_vm() {
    local app_name="$1"
    local machine_id="$2"

    if [[ -z "$machine_id" ]]; then
        local machine_info
        if ! machine_info=$(get_machine_info "$app_name"); then
            return 1
        fi
        machine_id=$(parse_machine_info "$machine_info" "id")
    fi

    print_status "Starting VM..."
    flyctl machine start "$machine_id" -a "$app_name"
    print_success "VM start command sent"
}

# Function to stop/suspend VM
stop_vm() {
    local app_name="$1"
    local machine_id="$2"

    if [[ -z "$machine_id" ]]; then
        local machine_info
        if ! machine_info=$(get_machine_info "$app_name"); then
            return 1
        fi
        machine_id=$(parse_machine_info "$machine_info" "id")
    fi

    print_status "Stopping VM..."
    flyctl machine stop "$machine_id" -a "$app_name"
    print_success "VM stop command sent"
}

# Function to check SSH connectivity
test_ssh_connection() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"
    local timeout="${4:-5}"

    ssh -o ConnectTimeout="$timeout" -o BatchMode=yes -p "$remote_port" "$remote_user@$remote_host" exit 2>/dev/null
}

# Function to wait for SSH to be available
wait_for_ssh() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"
    local max_wait="${4:-120}"

    print_status "Waiting for SSH service to be available..."

    local start_time
    start_time=$(date +%s)
    local retries=0
    local max_retries=$((max_wait / 2))

    while [[ $retries -lt $max_retries ]]; do
        if test_ssh_connection "$remote_host" "$remote_port" "$remote_user" 3; then
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

# Function to wait for VM to be fully ready
wait_for_vm_ready() {
    local app_name="$1"
    local remote_host="$2"
    local remote_port="$3"
    local remote_user="$4"
    local max_wait="${5:-120}"

    print_status "Waiting for VM to be fully operational..."

    local start_time
    start_time=$(date +%s)
    local retries=0
    local max_retries=$((max_wait / 2))

    # First, wait for machine state to be 'started'
    while [[ $retries -lt $max_retries ]]; do
        local current_state
        current_state=$(check_vm_status "$app_name")

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
    wait_for_ssh "$remote_host" "$remote_port" "$remote_user" $((max_wait - (retries * 2)))
}

# Function to execute remote command via SSH
execute_remote_command() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"
    local command="$4"

    ssh -p "$remote_port" "$remote_user@$remote_host" "$command"
}

# Function to execute remote script via SSH
execute_remote_script() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"
    local script="$4"

    ssh -p "$remote_port" "$remote_user@$remote_host" bash << EOF
$script
EOF
}

# Function to verify VM functionality
verify_vm_functionality() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"

    print_status "Verifying VM functionality..."

    execute_remote_script "$remote_host" "$remote_port" "$remote_user" '
echo "🔍 VM Functionality Check:"
echo "=========================="

echo "✅ SSH connection: Working"

echo -n "✅ Workspace mount: "
if [[ -d /workspace ]]; then
    echo "OK ($(df -h /workspace | awk '\''NR==2 {print $4}'\'' | head -1) available)"
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
find /workspace -maxdepth 2 -type d 2>/dev/null | head -5 | sed "s/^/   /"
'

    print_success "VM functionality verified"
}

# Function to gracefully shutdown VM processes
graceful_shutdown() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"

    print_status "Performing graceful shutdown..."

    # Check if SSH is accessible
    if ! test_ssh_connection "$remote_host" "$remote_port" "$remote_user" 5; then
        print_warning "SSH not accessible, skipping graceful shutdown"
        return 0
    fi

    execute_remote_script "$remote_host" "$remote_port" "$remote_user" '
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
'

    print_success "Graceful shutdown completed"
}

# Function to restore suspended sessions
restore_sessions() {
    local remote_host="$1"
    local remote_port="$2"
    local remote_user="$3"

    print_status "Checking for suspended sessions to restore..."

    execute_remote_script "$remote_host" "$remote_port" "$remote_user" '
# Check for tmux sessions
if command -v tmux >/dev/null 2>&1; then
    session_count=$(tmux list-sessions 2>/dev/null | wc -l || echo 0)
    if [[ $session_count -gt 0 ]]; then
        echo "🔄 Found $session_count tmux session(s):"
        tmux list-sessions 2>/dev/null | sed "s/^/   /"
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
    ls -1t /workspace/backups/suspend_backup_*.tar.gz | head -3 | sed "s/^/   /"
fi
'

    print_success "Session check completed"
}

# Function to show current VM status with details
show_vm_status() {
    local app_name="$1"
    local remote_host="$2"
    local remote_port="$3"
    local remote_user="$4"

    local current_state
    current_state=$(check_vm_status "$app_name")

    echo
    print_status "📊 Current Status:"

    case "$current_state" in
        "started")
            echo "  • VM Status: ✅ RUNNING"
            echo "  • Compute Costs: 💸 ACTIVE"

            if test_ssh_connection "$remote_host" "$remote_port" "$remote_user" 5; then
                echo "  • SSH Access: ✅ AVAILABLE"

                # Get additional info
                local uptime
                local load
                uptime=$(execute_remote_command "$remote_host" "$remote_port" "$remote_user" "uptime -p" 2>/dev/null || echo "unknown")
                load=$(execute_remote_command "$remote_host" "$remote_port" "$remote_user" "uptime | awk -F'load average:' '{print \$2}'" 2>/dev/null || echo "unknown")

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
            echo "  • Resume: Run resume script or connect via SSH/IDE"
            ;;
        *)
            echo "  • VM Status: ❓ $current_state"
            echo "  • Compute Costs: ❓ UNKNOWN"
            echo "  • SSH Access: ❓ UNKNOWN"
            ;;
    esac
}

# Function to show connection information
show_connection_info() {
    local app_name="$1"
    local remote_host="$2"
    local remote_port="$3"
    local remote_user="$4"

    print_success "🔌 VM Ready for Connection!"
    echo
    print_status "Connection Options:"
    echo "  • SSH: ssh $remote_user@$remote_host -p $remote_port"
    echo "  • VSCode Remote-SSH: Connect to configured host"
    echo "  • IntelliJ Gateway: Use existing SSH configuration"
    echo
    print_status "Quick Commands:"
    echo "  • Check status: ssh $remote_user@$remote_host -p $remote_port 'uptime'"
    echo "  • Start Claude: ssh $remote_user@$remote_host -p $remote_port 'cd /workspace && claude'"
    echo "  • View projects: ssh $remote_user@$remote_host -p $remote_port 'ls -la /workspace/projects/'"
    echo
    print_status "💡 Tips:"
    echo "  • Use tmux for persistent sessions: tmux new-session -s work"
    echo "  • All work should be in /workspace (persistent across suspends)"
    echo "  • VM will auto-suspend after period of inactivity"
}

# Export functions
export -f check_vm_status start_vm stop_vm test_ssh_connection wait_for_ssh
export -f wait_for_vm_ready execute_remote_command execute_remote_script
export -f verify_vm_functionality graceful_shutdown restore_sessions
export -f show_vm_status show_connection_info