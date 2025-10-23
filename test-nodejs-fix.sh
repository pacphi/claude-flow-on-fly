#!/bin/bash
# Test script to validate nodejs extension NVM compatibility fix
# This simulates the exact same steps as the CI integration test

set -e

echo "🧪 Testing nodejs extension NVM compatibility fix..."
echo ""

# Cleanup function
cleanup() {
  echo ""
  echo "🧹 Cleaning up..."
  docker rm -f sindri-test-nodejs 2>/dev/null || true
}

# Register cleanup on exit
trap cleanup EXIT

# Build minimal test container
echo "📦 Building test container..."
docker build -t sindri-test-nodejs -f - . <<'DOCKERFILE'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Install minimal dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Create test user
RUN useradd -m -s /bin/bash developer

# Copy extension files (matching production paths)
COPY docker/lib/extensions.d/nodejs.sh.example /workspace/scripts/lib/nodejs.sh
COPY docker/lib/extensions-common.sh /workspace/scripts/extensions-common.sh
RUN mkdir -p /workspace/scripts/lib/extensions.d

RUN chown -R developer:developer /workspace

USER developer
WORKDIR /home/developer

DOCKERFILE

echo "✅ Test container built"
echo ""

# Run the test in container
echo "🔬 Running nodejs extension test..."
docker run --name sindri-test-nodejs sindri-test-nodejs /bin/bash -c '
set -e

echo "Step 1: Installing nodejs extension..."
cd /workspace/scripts/lib
bash nodejs.sh install
echo "✅ Installation completed"
echo ""

echo "Step 2: Configuring nodejs extension..."
bash nodejs.sh configure
echo "✅ Configuration completed"
echo ""

echo "Step 3: Checking for NVM prefix conflict..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# This should NOT show the error anymore
if npm config get prefix 2>&1 | grep -q "npm-global"; then
  echo "❌ FAIL: npm prefix is still set to npm-global (conflicts with NVM)"
  exit 1
else
  echo "✅ PASS: npm prefix is NVM-managed"
fi
echo ""

echo "Step 4: Validating node command (CI validation step)..."
# This is the exact command from the CI test
if source ~/.nvm/nvm.sh 2>/dev/null && command -v node && node --version; then
  echo "✅ PASS: node command works"
else
  echo "❌ FAIL: node command validation failed"
  exit 1
fi
echo ""

echo "Step 5: Checking NVM compatibility..."
# This would show the error if prefix is misconfigured
if nvm current 2>&1 | grep -q "globalconfig.*incompatible"; then
  echo "❌ FAIL: NVM shows compatibility error"
  exit 1
else
  echo "✅ PASS: NVM has no compatibility errors"
fi
echo ""

echo "Step 6: Test npm global install (without sudo)..."
npm install -g cowsay 2>&1 | tee /tmp/npm-install.log
if grep -q "globalconfig.*incompatible" /tmp/npm-install.log; then
  echo "❌ FAIL: npm global install shows NVM incompatibility"
  exit 1
else
  echo "✅ PASS: npm global install works without errors"
fi
echo ""

echo "Step 7: Verify global package location..."
npm_prefix=$(npm config get prefix)
if [[ "$npm_prefix" == *".nvm"* ]]; then
  echo "✅ PASS: Global packages install to NVM directory: $npm_prefix"
else
  echo "❌ FAIL: Global packages not in NVM directory: $npm_prefix"
  exit 1
fi
echo ""

echo "🎉 All tests passed! The nodejs extension is NVM-compatible."
'

echo ""
echo "✅ Test completed successfully!"
echo "The fix resolves the NVM compatibility issue."
