#!/bin/bash
# Auto-start tmux workspace on SSH connection

# Only auto-start if we're in an SSH session and no tmux is running
if [[ -n "$SSH_CONNECTION" ]] && [[ -z "$TMUX" ]]; then
    # Check if there's an existing session
    if tmux has-session -t claude-workspace 2>/dev/null; then
        echo "🔗 Attaching to existing Claude workspace..."
        tmux attach-session -t claude-workspace
    else
        echo "🚀 Starting new Claude workspace..."
        /workspace/scripts/tmux-workspace.sh
    fi
fi
