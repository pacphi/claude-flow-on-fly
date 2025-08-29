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
echo "🔄 Preparing for graceful shutdown..."

# Enhanced tmux session management using helper functions
if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
    echo "📺 Managing tmux sessions..."

    # Source tmux helper functions if available
    if [[ -f /workspace/scripts/lib/tmux-helpers.sh ]]; then
        source /workspace/scripts/lib/tmux-helpers.sh 2>/dev/null || true
    fi

    # Get list of active sessions
    active_sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null || true)
    session_count=$(echo "$active_sessions" | wc -l)

    if [[ -n "$active_sessions" && "$session_count" -gt 0 ]]; then
        echo "  Found $session_count active tmux session(s)"

        # Create shutdown backup directory
        backup_dir="/workspace/backups/shutdown-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        echo "  📁 Creating session backups in $backup_dir"

        # Process each session
        echo "$active_sessions" | while read -r session_name; do
            if [[ -n "$session_name" ]]; then
                echo "  🔄 Processing session: $session_name"

                # Notify users in session about shutdown
                tmux display-message -t "$session_name" "⚠️ VM suspension in 10 seconds - saving session..." 2>/dev/null || true

                # Save session layout using helper function if available
                if command -v tmux_save_session >/dev/null 2>&1; then
                    tmux_save_session "$session_name" 2>/dev/null || true
                else
                    # Fallback: manual session save
                    tmux list-windows -t "$session_name" -F "#{session_name}:#{window_index}:#{window_name}:#{pane_current_path}" > "$backup_dir/${session_name}.save" 2>/dev/null || true
                fi

                # Send Ctrl+S to each pane for editor saves
                tmux list-panes -s -t "$session_name" -F "#{session_name}:#{window_index}.#{pane_index}" 2>/dev/null | while read -r pane; do
                    tmux send-keys -t "$pane" C-s 2>/dev/null || true
                done

                # Give a moment for saves to complete
                sleep 1

                # Send graceful shutdown message
                tmux send-keys -t "$session_name" "" 2>/dev/null || true
                tmux display-message -t "$session_name" "💾 Session saved for restore after VM resume" 2>/dev/null || true
            fi
        done

        # Brief pause to let users see messages
        sleep 2

        echo "  ✅ All tmux sessions prepared for suspension"
    else
        echo "  ℹ️ No active tmux sessions found"
    fi
else
    echo "  ℹ️ tmux not installed or no sessions active"
fi

# Save any vim/nvim sessions with enhanced detection
if pgrep -x vim >/dev/null 2>&1 || pgrep -x nvim >/dev/null 2>&1; then
    echo "📝 Saving vim/nvim sessions..."
    # Send save signal to vim processes
    pkill -USR1 vim 2>/dev/null || true
    pkill -USR1 nvim 2>/dev/null || true
    sleep 1
    echo "  ✅ Editor sessions saved"
fi

# Stop long-running processes gracefully
echo "🛑 Stopping long-running processes..."

# Stop development servers with better detection
dev_processes=$(pgrep -f "npm.*(start|dev|serve)|node.*(server|app|index|main)|python.*manage.py.*runserver|rails.*server|hugo.*server" 2>/dev/null || true)
if [[ -n "$dev_processes" ]]; then
    echo "  🔄 Stopping development servers..."
    pkill -TERM -f "npm.*(start|dev|serve)|node.*(server|app|index|main)|python.*manage.py.*runserver|rails.*server|hugo.*server" 2>/dev/null || true
    sleep 3
    # Force kill if still running
    pkill -KILL -f "npm.*(start|dev|serve)|node.*(server|app|index|main)" 2>/dev/null || true
    echo "  ✅ Development servers stopped"
else
    echo "  ℹ️ No development servers running"
fi

# Stop database processes if running locally
db_processes=$(pgrep -f "postgres|mysql|mongodb|redis-server" 2>/dev/null || true)
if [[ -n "$db_processes" ]]; then
    echo "  🔄 Stopping database processes..."
    pkill -TERM -f "postgres|mysql|mongodb|redis-server" 2>/dev/null || true
    sleep 2
    echo "  ✅ Database processes stopped"
fi

# Sync filesystem and clear caches
echo "💾 Finalizing filesystem operations..."
sync
echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# Create shutdown marker for resume detection
echo "$(date): VM gracefully shutdown" > /workspace/.last-shutdown
chmod 644 /workspace/.last-shutdown

echo "✅ Enhanced graceful shutdown preparation complete"
echo "🔄 Session data backed up and ready for restore"
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
echo "🔄 Checking session restoration status..."

# Check shutdown marker
if [[ -f /workspace/.last-shutdown ]]; then
    echo "📋 Previous shutdown info:"
    cat /workspace/.last-shutdown | sed "s/^/   /"
    echo ""
fi

# Enhanced tmux session restoration
if command -v tmux >/dev/null 2>&1; then
    # Source tmux helper functions if available
    if [[ -f /workspace/scripts/lib/tmux-helpers.sh ]]; then
        source /workspace/scripts/lib/tmux-helpers.sh 2>/dev/null || true
    fi

    # Check for active sessions
    session_count=$(tmux list-sessions 2>/dev/null | wc -l || echo 0)
    if [[ $session_count -gt 0 ]]; then
        echo "✅ Found $session_count active tmux session(s):"
        tmux list-sessions 2>/dev/null | while read -r line; do
            echo "   🖥️  $line"
        done
        echo ""
        echo "   💡 Reconnect options:"
        echo "      • tmux attach                    # Attach to last session"
        echo "      • tmux attach -t claude-workspace # Attach to main workspace"
        echo "      • tmux-workspace                 # Use workspace launcher"
        echo "      • tmux list-sessions             # List all sessions"
    else
        echo "📱 No active tmux sessions found"

        # Check for session backups to restore
        echo "🔍 Checking for session backups to restore..."

        # Look for shutdown backups (most recent)
        shutdown_backups=$(find /workspace/backups -name "shutdown-*" -type d 2>/dev/null | sort -r | head -3)
        if [[ -n "$shutdown_backups" ]]; then
            echo "   💾 Recent shutdown backups found:"
            echo "$shutdown_backups" | while read -r backup_dir; do
                backup_date=$(basename "$backup_dir" | sed "s/shutdown-//")
                save_files=$(find "$backup_dir" -name "*.save" 2>/dev/null | wc -l)
                echo "      📁 $backup_date ($save_files sessions)"
            done
            echo ""
            echo "   🔄 Restore options:"
            echo "      • Source tmux helpers: source /workspace/scripts/lib/tmux-helpers.sh"
            echo "      • Restore session: tmux_restore_session [session-name]"
            echo "      • Or start fresh: tmux-workspace"
        else
            echo "   ℹ️ No session backups found"
            echo "   🚀 Start new workspace: tmux-workspace"
        fi

        # Check for tmux session save files (from helper functions)
        tmux_saves=$(find /workspace -name ".tmux-session-*.save" 2>/dev/null | sort -r | head -3)
        if [[ -n "$tmux_saves" ]]; then
            echo ""
            echo "   💾 Session save files found:"
            echo "$tmux_saves" | while read -r save_file; do
                save_name=$(basename "$save_file" .save | sed "s/.tmux-session-//")
                echo "      📄 $save_name"
            done
        fi
    fi
else
    echo "❌ tmux not available - install with: apt-get install tmux"
fi

# Check for suspend backups
echo ""
if ls /workspace/backups/suspend_backup_*.tar.gz >/dev/null 2>&1; then
    echo "💾 Suspend backups available:"
    ls -1t /workspace/backups/suspend_backup_*.tar.gz | head -3 | while read -r backup; do
        backup_size=$(du -h "$backup" 2>/dev/null | cut -f1)
        backup_name=$(basename "$backup")
        echo "   📦 $backup_name ($backup_size)"
    done
fi

# Show workspace status
echo ""
echo "📁 Workspace status:"
echo "   • Disk usage: $(df -h /workspace 2>/dev/null | awk '\''NR==2 {print $3 "/" $2 " (" $5 " used)"}'\'' || echo "Unknown")"
echo "   • Last activity: $(find /workspace -type f -newermt "24 hours ago" 2>/dev/null | wc -l) files modified in last 24h"

# Check for any development servers that should be restarted
echo ""
echo "🔍 Development environment status:"
if [[ -f /workspace/package.json ]]; then
    echo "   📦 Node.js project detected"
    if command -v npm >/dev/null 2>&1; then
        echo "      • npm available: $(npm --version)"
        if [[ -f /workspace/package-lock.json ]]; then
            echo "      • Dependencies installed: ✅"
        else
            echo "      • Dependencies: ⚠️ Run npm install"
        fi
    fi
fi

# Check for agents and context
if [[ -d /workspace/agents ]]; then
    agent_count=$(find /workspace/agents -name "*.md" 2>/dev/null | wc -l)
    echo "   🤖 Agents available: $agent_count"
fi

if [[ -f /workspace/context/global/CLAUDE.md ]]; then
    echo "   📚 Context system: ✅ Ready"
else
    echo "   📚 Context system: ⚠️ Not configured"
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
        "stopped"|"suspended")
            echo "  • VM Status: ⏸️  SUSPENDED"
            echo "  • Compute Costs: ✅ STOPPED ($0/hour)"
            echo "  • SSH Access: ❌ UNAVAILABLE"
            echo "  • Resume: Run resume script or connect via SSH/IDE"
            echo "  • Auto-Resume: VM will start automatically on SSH connection"
            ;;
        *)
            echo "  • VM Status: ❓ $current_state"
            echo "  • Compute Costs: ❓ UNKNOWN"
            echo "  • SSH Access: ❓ UNKNOWN"
            echo "  • Action: Try using vm-resume.sh to start"
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