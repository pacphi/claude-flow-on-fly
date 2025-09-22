#!/bin/bash

# prepare-fly-config.sh
# Script to prepare fly.toml for deployment by substituting template variables
# Usage: ./scripts/prepare-fly-config.sh [--ci-mode]

set -euo pipefail

# Default values
APP_NAME="${APP_NAME:-}"
REGION="${REGION:-iad}"
VOLUME_NAME="${VOLUME_NAME:-claude_data}"
VOLUME_SIZE="${VOLUME_SIZE:-30}"
VM_MEMORY="${VM_MEMORY:-8192}"
CPU_KIND="${CPU_KIND:-shared}"
CPU_COUNT="${CPU_COUNT:-4}"
SSH_EXTERNAL_PORT="${SSH_EXTERNAL_PORT:-10022}"
CI_MODE="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --ci-mode)
      CI_MODE="true"
      shift
      ;;
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  --ci-mode          Configure for CI testing (removes external port mapping)"
      echo "  --app-name NAME    Set app name"
      echo "  --region REGION    Set region (default: iad)"
      echo "  --help             Show this help message"
      echo ""
      echo "Environment variables can be used to set other values:"
      echo "  VOLUME_NAME, VOLUME_SIZE, VM_MEMORY, CPU_KIND, CPU_COUNT, SSH_EXTERNAL_PORT"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$APP_NAME" ]]; then
  echo "Error: APP_NAME must be set either via environment variable or --app-name option"
  exit 1
fi

echo "Preparing fly.toml configuration..."
echo "  App name: $APP_NAME"
echo "  Region: $REGION"
echo "  CI Mode: $CI_MODE"

# Create working copy
cp fly.toml fly.toml.tmp

# Replace template variables
sed -i "s/{{APP_NAME}}/$APP_NAME/g" fly.toml.tmp
sed -i "s/{{REGION}}/$REGION/g" fly.toml.tmp
sed -i "s/{{VOLUME_NAME}}/$VOLUME_NAME/g" fly.toml.tmp
sed -i "s/{{VOLUME_SIZE}}/$VOLUME_SIZE/g" fly.toml.tmp
sed -i "s/{{VM_MEMORY}}/$VM_MEMORY/g" fly.toml.tmp
sed -i "s/{{CPU_KIND}}/$CPU_KIND/g" fly.toml.tmp
sed -i "s/{{CPU_COUNT}}/$CPU_COUNT/g" fly.toml.tmp
sed -i "s/{{SSH_EXTERNAL_PORT}}/$SSH_EXTERNAL_PORT/g" fly.toml.tmp

# Handle CI mode - remove external port mapping to prevent conflicts
if [[ "$CI_MODE" == "true" ]]; then
  echo "  CI Mode: Removing external port mapping to prevent conflicts"
  # Remove the [[services.ports]] section entirely for CI
  sed -i '/# Port mapping for SSH access/,+2d' fly.toml.tmp
fi

# Replace the original file
mv fly.toml.tmp fly.toml

echo "✅ fly.toml configuration prepared successfully"

# Validate the configuration
if command -v flyctl &> /dev/null; then
  echo "Validating fly.toml..."
  if flyctl config validate --config fly.toml; then
    echo "✅ fly.toml validation passed"
  else
    echo "❌ fly.toml validation failed"
    exit 1
  fi
else
  echo "⚠️  flyctl not found - skipping validation"
fi