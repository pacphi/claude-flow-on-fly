#!/bin/bash
# Tmux Helper Functions for Claude Development

SESSION_NAME="${TMUX_SESSION_NAME:-claude-workspace}"

# Function to check if session exists
tmux_session_exists() {
    local session_name="${1:-$SESSION_NAME}"
    tmux has-session -t "$session_name" 2>/dev/null
}

# Function to create a new window in existing session
tmux_new_window() {
    local window_name="$1"
    local session_name="${2:-$SESSION_NAME}"

    if tmux_session_exists "$session_name"; then
        tmux new-window -t "$session_name" -n "$window_name" -c "/workspace"
        echo "✅ Created window: $window_name"
    else
        echo "❌ Session $session_name not found"
        return 1
    fi
}

# Function to send command to specific window
tmux_send_command() {
    local window_id="$1"
    local command="$2"
    local session_name="${3:-$SESSION_NAME}"

    if tmux_session_exists "$session_name"; then
        tmux send-keys -t "$session_name:$window_id" "$command" C-m
        echo "✅ Sent command to window $window_id: $command"
    else
        echo "❌ Session $session_name not found"
        return 1
    fi
}

# Function to list all sessions
tmux_list_sessions() {
    tmux list-sessions 2>/dev/null | grep -E "^[^:]+:" | cut -d: -f1
}

# Function to kill all Claude sessions
tmux_cleanup() {
    local sessions
    sessions=$(tmux_list_sessions | grep -i claude 2>/dev/null || true)

    if [[ -n "$sessions" ]]; then
        echo "🧹 Cleaning up Claude tmux sessions..."
        echo "$sessions" | while read -r session; do
            tmux kill-session -t "$session" 2>/dev/null && echo "✅ Killed session: $session"
        done
    else
        echo "No Claude sessions found"
    fi
}

# Function to show session status
tmux_status() {
    echo "📊 Tmux Session Status"
    echo "===================="

    if tmux_session_exists; then
        echo "✅ Main session: $SESSION_NAME (active)"
        echo ""
        echo "Windows:"
        tmux list-windows -t "$SESSION_NAME" 2>/dev/null | while read -r line; do
            echo "  $line"
        done
        echo ""
        echo "Panes:"
        tmux list-panes -s -t "$SESSION_NAME" 2>/dev/null | while read -r line; do
            echo "  $line"
        done
    else
        echo "❌ Main session: $SESSION_NAME (not running)"
    fi

    echo ""
    echo "All sessions:"
    local all_sessions
    all_sessions=$(tmux_list_sessions)
    if [[ -n "$all_sessions" ]]; then
        echo "$all_sessions" | while read -r session; do
            echo "  - $session"
        done
    else
        echo "  (none)"
    fi
}

# Function to create development-focused window layout
tmux_dev_layout() {
    local session_name="${1:-$SESSION_NAME}"
    local project_dir="${2:-/workspace}"

    if ! tmux_session_exists "$session_name"; then
        echo "❌ Session $session_name not found"
        return 1
    fi

    # Create or select development window
    if tmux list-windows -t "$session_name" | grep -q "dev"; then
        tmux select-window -t "$session_name:dev"
    else
        tmux new-window -t "$session_name" -n "dev" -c "$project_dir"
    fi

    # Split into 3 panes: editor, terminal, logs
    tmux split-window -h -t "$session_name:dev" -c "$project_dir"
    tmux split-window -v -t "$session_name:dev.1" -c "$project_dir"

    # Select main editing pane
    tmux select-pane -t "$session_name:dev.0"

    echo "✅ Development layout created in session $session_name"
}

# Function to save session layout
tmux_save_session() {
    local session_name="${1:-$SESSION_NAME}"
    local save_file="/workspace/.tmux-session-${session_name}.save"

    if ! tmux_session_exists "$session_name"; then
        echo "❌ Session $session_name not found"
        return 1
    fi

    # Save session information
    {
        echo "# Tmux session save for $session_name"
        echo "# Generated: $(date)"
        echo ""

        tmux list-windows -t "$session_name" -F "#{window_index}:#{window_name}:#{pane_current_path}"
    } > "$save_file"

    echo "✅ Session $session_name saved to $save_file"
}

# Function to restore session layout
tmux_restore_session() {
    local session_name="${1:-$SESSION_NAME}"
    local save_file="/workspace/.tmux-session-${session_name}.save"

    if [[ ! -f "$save_file" ]]; then
        echo "❌ Save file not found: $save_file"
        return 1
    fi

    echo "🔄 Restoring session $session_name from $save_file"
    echo "Note: This is a basic restore - manual adjustment may be needed"

    # Read save file and recreate windows
    grep -v "^#" "$save_file" | while IFS=':' read -r index name path; do
        if [[ -n "$index" && -n "$name" && -n "$path" ]]; then
            echo "Creating window $index: $name in $path"
            tmux new-window -t "$session_name:$index" -n "$name" -c "$path" 2>/dev/null || true
        fi
    done
}

# Export functions
export -f tmux_session_exists
export -f tmux_new_window
export -f tmux_send_command
export -f tmux_list_sessions
export -f tmux_cleanup
export -f tmux_status
export -f tmux_dev_layout
export -f tmux_save_session
export -f tmux_restore_session
