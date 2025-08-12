#!/bin/bash
# common.sh - Shared utilities for all scripts
# This library provides common functions, colors, and utilities used across the project

# Prevent multiple sourcing
if [[ "${COMMON_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
COMMON_SH_LOADED="true"

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export MAGENTA='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Common directories
export WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
export SCRIPTS_DIR="${SCRIPTS_DIR:-$WORKSPACE_DIR/scripts}"
export PROJECTS_DIR="${PROJECTS_DIR:-$WORKSPACE_DIR/projects}"
export BACKUPS_DIR="${BACKUPS_DIR:-$WORKSPACE_DIR/backups}"
export CONFIG_DIR="${CONFIG_DIR:-$WORKSPACE_DIR/.config}"
export EXTENSIONS_DIR="${EXTENSIONS_DIR:-$SCRIPTS_DIR/extensions.d}"

# Function to print colored output
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

print_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running in Docker/VM environment
is_in_vm() {
    [[ -d "/workspace" ]] && [[ -f "/.dockerenv" || -d "/fly" ]]
}

# Function to ensure script is run with proper permissions
ensure_permissions() {
    local required_user="${1:-developer}"
    if [[ "$USER" != "$required_user" ]] && [[ "$USER" != "root" ]]; then
        print_error "This script should be run as $required_user or root"
        return 1
    fi
    return 0
}

# Function to create directory with proper ownership
create_directory() {
    local dir="$1"
    local owner="${2:-developer:developer}"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        if [[ "$USER" == "root" ]]; then
            chown "$owner" "$dir"
        fi
        print_debug "Created directory: $dir"
    fi
}

# Function to safely copy files
safe_copy() {
    local src="$1"
    local dest="$2"
    local owner="${3:-developer:developer}"

    if [[ -f "$src" ]]; then
        cp "$src" "$dest"
        if [[ "$USER" == "root" ]]; then
            chown "$owner" "$dest"
        fi
        chmod +x "$dest" 2>/dev/null || true
        print_debug "Copied $src to $dest"
        return 0
    else
        print_warning "Source file not found: $src"
        return 1
    fi
}

# Function to check for required environment variables
check_env_var() {
    local var_name="$1"
    local var_value="${!var_name}"

    if [[ -z "$var_value" ]]; then
        print_warning "Environment variable $var_name is not set"
        return 1
    fi
    return 0
}

# Function to prompt for user confirmation
confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-n}"

    local yn_prompt="y/N"
    if [[ "${default,,}" == "y" ]]; then
        yn_prompt="Y/n"
    fi

    read -p "$prompt ($yn_prompt): " -n 1 -r
    echo

    if [[ -z "$REPLY" ]]; then
        REPLY="$default"
    fi

    [[ "$REPLY" =~ ^[Yy]$ ]]
}

# Function to run command with error handling
run_command() {
    local cmd="$1"
    local error_msg="${2:-Command failed}"

    print_debug "Running: $cmd"

    if eval "$cmd"; then
        return 0
    else
        print_error "$error_msg"
        return 1
    fi
}

# Function to check disk space
check_disk_space() {
    local path="${1:-/workspace}"
    local min_space_gb="${2:-1}"

    local available_kb=$(df "$path" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))

    if [[ $available_gb -lt $min_space_gb ]]; then
        print_warning "Low disk space: ${available_gb}GB available (minimum: ${min_space_gb}GB)"
        return 1
    fi

    print_debug "Disk space check passed: ${available_gb}GB available"
    return 0
}

# Function to get timestamp
get_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Function to create backup filename
get_backup_filename() {
    local prefix="${1:-backup}"
    echo "${prefix}_$(get_timestamp).tar.gz"
}

# Function to load configuration file
load_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]]; then
        # shellcheck source=/dev/null
        source "$config_file"
        print_debug "Loaded configuration from $config_file"
        return 0
    else
        print_debug "Configuration file not found: $config_file"
        return 1
    fi
}

# Function to write configuration file
save_config() {
    local config_file="$1"
    shift

    {
        echo "# Configuration saved on $(date)"
        for var in "$@"; do
            echo "export $var=\"${!var}\""
        done
    } > "$config_file"

    print_debug "Saved configuration to $config_file"
}

# Function to check network connectivity
check_network() {
    local test_host="${1:-8.8.8.8}"
    local timeout="${2:-5}"

    if ping -c 1 -W "$timeout" "$test_host" >/dev/null 2>&1; then
        print_debug "Network connectivity check passed"
        return 0
    else
        print_warning "Network connectivity check failed"
        return 1
    fi
}

# Function to retry command with backoff
retry_with_backoff() {
    local max_attempts="${1:-3}"
    local initial_delay="${2:-1}"
    shift 2
    local cmd="$*"

    local attempt=1
    local delay="$initial_delay"

    while [[ $attempt -le $max_attempts ]]; do
        print_debug "Attempt $attempt of $max_attempts: $cmd"

        if eval "$cmd"; then
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            print_warning "Command failed, retrying in ${delay}s..."
            sleep "$delay"
            delay=$((delay * 2))
        fi

        attempt=$((attempt + 1))
    done

    print_error "Command failed after $max_attempts attempts"
    return 1
}

# Function to display a spinner for long-running operations
spinner() {
    local pid="$1"
    local message="${2:-Processing...}"
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

    echo -n "$message "
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep 0.1
        printf "\b\b\b"
    done
    echo " Done"
}

# Export all functions so they're available to subshells
export -f print_status print_success print_warning print_error print_debug
export -f command_exists is_in_vm ensure_permissions create_directory
export -f safe_copy check_env_var confirm run_command check_disk_space
export -f get_timestamp get_backup_filename load_config save_config
export -f check_network retry_with_backoff spinner