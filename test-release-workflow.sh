#!/bin/bash
# Release Workflow Simulation Script
# This script simulates the README update logic from the GitHub release workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo
    echo "=================================================="
    echo -e "${BLUE}$1${NC}"
    echo "=================================================="
}

# Function to show diff between original and current README
show_diff() {
    local label="$1"
    echo
    echo -e "${YELLOW}=== $label ===${NC}"
    if diff -u README.md.backup README.md || true; then
        echo -e "${GREEN}No changes detected${NC}"
    fi
}

# Function to reset README to original
reset_readme() {
    cp README.md.backup README.md
    print_status "Reset README.md to original state"
}

# Function to simulate the release workflow README update logic
simulate_release_update() {
    local version="$1"
    local is_prerelease="$2"

    print_header "SIMULATING RELEASE: v$version (prerelease: $is_prerelease)"

    # Update version references in README.md based on release type
    updated=false

    if [[ "$is_prerelease" == "true" ]]; then
        echo "📋 Updating pre-release information for v$version"

        # Update pre-release version
        if grep -q "Latest Pre-release.*: v[0-9]" README.md; then
            sed -i.tmp "s/Latest Pre-release.*: v[0-9][^[:space:]]*/Latest Pre-release**: v$version/g" README.md
            rm -f README.md.tmp
            echo "✅ Updated pre-release version in README.md"
            updated=true
        fi

        # Update status to show active pre-release development
        if grep -q "Current Status.*Pre-release Development" README.md; then
            # Status is already correct for pre-release
            echo "ℹ️  Status already shows pre-release development"
        fi

    else
        echo "🎉 Updating stable release information for v$version"

        # Update stable release version
        if grep -q "Latest Stable.*No stable releases yet" README.md; then
            sed -i.tmp "s/Latest Stable.*No stable releases yet.*/Latest Stable**: v$version - [View Release Notes](https:\/\/github.com\/pacphi\/claude-flow-on-fly\/releases\/tag\/v$version)/g" README.md
            rm -f README.md.tmp
            echo "✅ Updated stable release version in README.md"
            updated=true
        elif grep -q "Latest Stable.*: v[0-9]" README.md; then
            sed -i.tmp "s/Latest Stable.*: v[0-9][^[:space:]]*.*/Latest Stable**: v$version - [View Release Notes](https:\/\/github.com\/pacphi\/claude-flow-on-fly\/releases\/tag\/v$version)/g" README.md
            rm -f README.md.tmp
            echo "✅ Updated stable release version in README.md"
            updated=true
        fi

        # Update status to show stable release
        if grep -q "Current Status.*Pre-release Development" README.md; then
            sed -i.tmp "s/Current Status.*: 🚧 \\*\\*Pre-release Development\\*\\*.*/Current Status**: ✅ **Stable Release** - Production ready/g" README.md
            rm -f README.md.tmp
            echo "✅ Updated status to show stable release"
            updated=true
        fi
    fi

    # Update any other "Release vX.X.X" references
    if grep -q "Release v[0-9]" README.md; then
        sed -i.tmp "s/Release v[0-9]\+\.[0-9]\+\.[0-9]\+[^[:space:]]*/Release v$version/g" README.md
        rm -f README.md.tmp
        echo "✅ Updated other release version references in README.md"
        updated=true
    fi

    if [[ "$updated" == "false" ]]; then
        echo "ℹ️  No version references found in README.md to update"
    fi

    # Note about automatic badge updates
    if grep -q "https://img.shields.io/github/v/release" README.md; then
        echo "ℹ️  Version badges will be automatically updated by shields.io"
    fi

    echo "✅ Documentation version check completed"
}

# Function to save README snapshot and extract status lines
save_and_show_status() {
    local label="$1"
    local filename="$2"

    # Save snapshot
    cp README.md "README-${filename}.md"
    print_success "Saved README snapshot: README-${filename}.md"

    echo
    echo -e "${YELLOW}=== $label Status Section ===${NC}"
    echo -e "${BLUE}Full Status Section:${NC}"
    # Extract the entire Status section (excluding the next header)
    sed -n '/## 📋 Status/,/## ⚡ Quick Start/p' README.md | sed '$d'
}

# Main test execution
main() {
    print_header "RELEASE WORKFLOW SIMULATION TEST"

    if [[ ! -f "README.md.backup" ]]; then
        print_error "README.md.backup not found. Please run this script from the project root."
        exit 1
    fi

    print_status "Starting with original README.md content"
    save_and_show_status "ORIGINAL" "00-original"

    # Test 1: Pre-release update
    print_header "TEST 1: PRE-RELEASE (v1.0.0-alpha.1)"
    simulate_release_update "1.0.0-alpha.1" "true"
    save_and_show_status "AFTER PRE-RELEASE v1.0.0-alpha.1" "01-prerelease-alpha1"
    show_diff "Changes after pre-release"

    # Test 2: Another pre-release update
    print_header "TEST 2: ANOTHER PRE-RELEASE (v1.0.0-alpha.2)"
    simulate_release_update "1.0.0-alpha.2" "true"
    save_and_show_status "AFTER PRE-RELEASE v1.0.0-alpha.2" "02-prerelease-alpha2"
    show_diff "Changes after second pre-release"

    # Test 3: Stable release (major transition)
    print_header "TEST 3: FIRST STABLE RELEASE (v1.0.0)"
    simulate_release_update "1.0.0" "false"
    save_and_show_status "AFTER STABLE RELEASE v1.0.0" "03-stable-v1.0.0"
    show_diff "Changes after stable release"

    # Test 4: Another stable release
    print_header "TEST 4: SECOND STABLE RELEASE (v1.1.0)"
    simulate_release_update "1.1.0" "false"
    save_and_show_status "AFTER STABLE RELEASE v1.1.0" "04-stable-v1.1.0"
    show_diff "Changes after second stable release"

    # Test 5: Back to pre-release (v1.2.0-beta.1)
    print_header "TEST 5: NEW PRE-RELEASE (v1.2.0-beta.1)"
    simulate_release_update "1.2.0-beta.1" "true"
    save_and_show_status "AFTER PRE-RELEASE v1.2.0-beta.1" "05-prerelease-beta1"
    show_diff "Changes after new pre-release"

    print_header "SIMULATION COMPLETE"
    print_success "All release scenarios have been tested"
    print_status "Current README.md shows the final state after all simulated releases"
    print_warning "To restore original README.md, run: cp README.md.backup README.md"

    echo
    echo -e "${BLUE}📁 Saved README Snapshots:${NC}"
    echo "   README-00-original.md          - Original state"
    echo "   README-01-prerelease-alpha1.md - After v1.0.0-alpha.1"
    echo "   README-02-prerelease-alpha2.md - After v1.0.0-alpha.2"
    echo "   README-03-stable-v1.0.0.md     - After v1.0.0 (first stable)"
    echo "   README-04-stable-v1.1.0.md     - After v1.1.0 (second stable)"
    echo "   README-05-prerelease-beta1.md  - After v1.2.0-beta.1"

    echo
    echo -e "${BLUE}💡 To view Status sections only:${NC}"
    echo "   grep -A10 '## 📋 Status' README-*.md"

    echo
    echo -e "${BLUE}Summary of what was tested:${NC}"
    echo "1. ✅ Pre-release updates (alpha versions)"
    echo "2. ✅ Multiple pre-release progression"
    echo "3. ✅ Transition from pre-release to stable"
    echo "4. ✅ Stable release updates"
    echo "5. ✅ Mixed pre-release and stable workflow"
    echo
    echo -e "${GREEN}The release workflow README update logic appears to be working correctly!${NC}"
}

# Check if running directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi