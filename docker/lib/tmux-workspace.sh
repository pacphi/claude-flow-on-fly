#!/bin/bash
# Tmux Workspace Launcher for Turbo Flow Claude Development

set -e

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
SESSION_NAME="claude-workspace"

print_status() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Function to check if session exists
session_exists() {
    tmux has-session -t "$SESSION_NAME" 2>/dev/null
}

# Function to create new workspace session
create_workspace_session() {
    print_status "🔧 Creating Claude workspace session..."

    # Ensure we're in the workspace directory
    cd "$WORKSPACE_DIR" || {
        print_error "Workspace directory not found: $WORKSPACE_DIR"
        return 1
    }

    # Kill existing session if it exists
    if session_exists; then
        print_status "Killing existing session..."
        tmux kill-session -t "$SESSION_NAME"
    fi

    # Create new session with first window for Claude
    print_status "Creating session with Claude-1 window..."
    tmux new-session -d -s "$SESSION_NAME" -n "Claude-1" -c "$WORKSPACE_DIR"

    # Create second window for Claude
    print_status "Creating Claude-2 window..."
    tmux new-window -t "$SESSION_NAME":1 -n "Claude-2" -c "$WORKSPACE_DIR"

    # Create third window for Claude monitor
    print_status "Creating Claude-Monitor window..."
    tmux new-window -t "$SESSION_NAME":2 -n "Claude-Monitor" -c "$WORKSPACE_DIR"

    # Create fourth window for htop
    print_status "Creating htop window..."
    tmux new-window -t "$SESSION_NAME":3 -n "htop" -c "$WORKSPACE_DIR"

    # Set up Claude Monitor window
    if command -v claude-monitor >/dev/null 2>&1; then
        tmux send-keys -t "$SESSION_NAME":2 "claude-monitor" C-m
    elif command -v claude-usage-cli >/dev/null 2>&1; then
        tmux send-keys -t "$SESSION_NAME":2 "claude-usage-cli" C-m
    else
        tmux send-keys -t "$SESSION_NAME":2 "echo 'Claude monitor tools not installed'" C-m
        tmux send-keys -t "$SESSION_NAME":2 "echo 'Run: pip install claude-monitor'" C-m
        tmux send-keys -t "$SESSION_NAME":2 "echo 'Or: npm install -g claude-usage-cli'" C-m
    fi

    # Start htop in window 3
    if command -v htop >/dev/null 2>&1; then
        tmux send-keys -t "$SESSION_NAME":3 "htop" C-m
    else
        tmux send-keys -t "$SESSION_NAME":3 "echo 'htop not installed. Run: sudo apt-get install -y htop'" C-m
    fi

    # Send helpful messages to Claude windows
    setup_claude_windows

    # Select the first window
    tmux select-window -t "$SESSION_NAME":0

    print_success "✅ Claude workspace session created successfully!"
}

# Function to set up Claude windows with helpful information
setup_claude_windows() {
    # Window 0 - Claude-1 (Primary)
    tmux send-keys -t "$SESSION_NAME":0 "clear" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo '=== Claude Workspace Window 1 (Primary) ==='" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo 'Workspace: $WORKSPACE_DIR'" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo 'Agents: \$(agent-count 2>/dev/null || echo \"Not configured\") available'" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo ''" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo 'Quick Commands:'" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo '  claude                    # Start Claude Code'" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo '  agent-list               # List available agents'" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo '  load-context             # View context files'" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo '  cf-with-context.sh swarm # Claude Flow with context'" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo ''" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo 'Mandatory agents:'" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo '  doc-planner.md           # Documentation planning'" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo '  microtask-breakdown.md   # Task decomposition'" C-m
    tmux send-keys -t "$SESSION_NAME":0 "echo ''" C-m

    # Window 1 - Claude-2 (Secondary)
    tmux send-keys -t "$SESSION_NAME":1 "clear" C-m
    tmux send-keys -t "$SESSION_NAME":1 "echo '=== Claude Workspace Window 2 (Secondary) ==='" C-m
    tmux send-keys -t "$SESSION_NAME":1 "echo 'Workspace: $WORKSPACE_DIR'" C-m
    tmux send-keys -t "$SESSION_NAME":1 "echo ''" C-m
    tmux send-keys -t "$SESSION_NAME":1 "echo 'Use this window for:'" C-m
    tmux send-keys -t "$SESSION_NAME":1 "echo '  - Parallel Claude sessions'" C-m
    tmux send-keys -t "$SESSION_NAME":1 "echo '  - Testing and validation'" C-m
    tmux send-keys -t "$SESSION_NAME":1 "echo '  - System commands'" C-m
    tmux send-keys -t "$SESSION_NAME":1 "echo ''" C-m
}

# Function to attach or create session
main() {
    print_status "🚀 Starting Claude Tmux Workspace..."

    # Check if tmux is installed
    if ! command -v tmux >/dev/null 2>&1; then
        print_error "tmux is not installed"
        return 1
    fi

    # Parse arguments
    local force_new=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --new|--force)
                force_new=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--new|--force] [--help]"
                echo ""
                echo "Options:"
                echo "  --new, --force    Create new session (kill existing if present)"
                echo "  --help            Show this help message"
                echo ""
                echo "Tmux Commands (once inside):"
                echo "  Ctrl+B, then:"
                echo "    0-3        Switch to window 0-3"
                echo "    c          Create new window"
                echo "    n          Next window"
                echo "    p          Previous window"
                echo "    d          Detach from session"
                echo "    |          Split pane vertically"
                echo "    -          Split pane horizontally"
                echo ""
                echo "To reattach: tmux attach -t $SESSION_NAME"
                return 0
                ;;
            *)
                print_error "Unknown option: $1"
                return 1
                ;;
        esac
    done

    # Create or attach to session
    if session_exists && [[ "$force_new" != true ]]; then
        print_status "Attaching to existing session..."
        tmux attach-session -t "$SESSION_NAME"
    else
        create_workspace_session
        print_status "📝 Attaching to tmux session..."
        tmux attach-session -t "$SESSION_NAME"
    fi
}

# Execute main function
main "$@"
