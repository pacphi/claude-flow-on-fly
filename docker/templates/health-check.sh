#!/bin/bash
# Health check script for Docker container

# Check if SSH daemon is running
if pgrep sshd > /dev/null; then
    exit 0
else
    exit 1
fi