#!/bin/bash
# Health check script for Docker container

# In CI mode, we use Fly.io's hallpass SSH instead of custom sshd
# Health check should pass as long as the container is running
if [ "$CI_MODE" = "true" ]; then
    exit 0
fi

# In production mode, check if SSH daemon is running
if pgrep sshd > /dev/null; then
    exit 0
else
    exit 1
fi