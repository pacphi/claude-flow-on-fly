#!/bin/bash
# fly-common.sh - Shared utilities for Fly.io management scripts
# This library provides common functions, colors, and utilities used across all Fly.io scripts

# Prevent multiple sourcing
if [[ "${FLY_COMMON_SH_LOADED:-}" == "true" ]]; then
    return 0
fi
FLY_COMMON_SH_LOADED="true"

# Colors for output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export PURPLE='\033[0;35m'
export NC='\033[0m' # No Color

# Common configuration
export DEFAULT_APP_NAME="claude-dev-env"
export DEFAULT_REMOTE_USER="developer"
export DEFAULT_REMOTE_PORT="10022"
export DEFAULT_VOLUME_NAME="claude_data"
export DEFAULT_REGION="iad"

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

print_header() {
    echo -e "${CYAN}$1${NC}"
}

print_metric() {
    echo -e "${PURPLE}$1${NC} $2"
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

# Function to get current timestamp
get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Function to get backup timestamp
get_backup_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Function to check if flyctl is installed and authenticated
check_flyctl() {
    if ! command_exists flyctl; then
        print_error "Fly.io CLI (flyctl) is not installed."
        print_status "Please install it from: https://fly.io/docs/getting-started/installing-flyctl/"
        exit 1
    fi

    # Check if authenticated
    if ! flyctl auth whoami >/dev/null 2>&1; then
        print_error "You are not authenticated with Fly.io."
        print_status "Please run: flyctl auth login"
        exit 1
    fi

    print_success "Fly.io CLI is installed and authenticated"
}

# Function to check required tools
check_prerequisites() {
    local required_tools=("flyctl" "$@")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        case "${missing_tools[0]}" in
            "jq")
                print_status "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
                ;;
            "bc")
                print_status "Install with: brew install bc (macOS) or apt-get install bc (Linux)"
                ;;
            "rsync")
                print_status "Install with: brew install rsync (macOS) or apt-get install rsync (Linux)"
                ;;
        esac
        exit 1
    fi
}

# Function to validate app name
validate_app_name() {
    local app_name="$1"

    if [[ -z "$app_name" ]]; then
        print_error "No app name specified."
        print_status "Use --app-name <name> or set APP_NAME environment variable"
        exit 1
    fi
}

# Function to check if app exists
check_app_exists() {
    local app_name="$1"

    validate_app_name "$app_name"

    if ! flyctl apps list | grep -q "^$app_name"; then
        print_error "Application $app_name not found."
        print_status "Available apps:"
        flyctl apps list | head -5
        exit 1
    fi
}

# Function to set up remote connection variables
setup_remote_vars() {
    local app_name="$1"
    validate_app_name "$app_name"

    export REMOTE_HOST="$app_name.fly.dev"
    export REMOTE_USER="${REMOTE_USER:-$DEFAULT_REMOTE_USER}"
    export REMOTE_PORT="${REMOTE_PORT:-$DEFAULT_REMOTE_PORT}"
}

# Function to confirm action with user
confirm_action() {
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

# Function to parse common arguments
parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-name)
                export APP_NAME="$2"
                shift 2
                ;;
            --help)
                if declare -f show_help >/dev/null; then
                    show_help
                else
                    echo "Help function not implemented for this script"
                fi
                exit 0
                ;;
            *)
                # Return unprocessed arguments
                echo "$@"
                return 0
                ;;
        esac
    done
}

# Function to show common usage patterns
show_common_usage() {
    local script_name="$1"
    echo "Common Options:"
    echo "  --app-name NAME     Fly.io app name (default: claude-dev-env)"
    echo "  --help              Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  APP_NAME            Fly.io application name"
    echo ""
}

# Function to get machine information (returns pipe-delimited format)
get_machine_info() {
    local app_name="$1"

    local machine_info
    if ! machine_info=$(flyctl machine list -a "$app_name" --json 2>/dev/null); then
        print_error "Failed to get machine information"
        return 1
    fi

    # Check if we have valid JSON and at least one machine
    if ! echo "$machine_info" | jq -e '.[0]' >/dev/null 2>&1; then
        print_error "No machines found or invalid response"
        return 1
    fi

    local machine_id machine_name machine_state machine_region cpu_kind cpus memory_mb machine_created

    # Extract values with better error handling
    machine_id=$(echo "$machine_info" | jq -r 'if .[0].id then .[0].id else "unknown" end' 2>/dev/null)
    machine_name=$(echo "$machine_info" | jq -r 'if .[0].name then .[0].name else "unknown" end' 2>/dev/null)
    machine_state=$(echo "$machine_info" | jq -r 'if .[0].state then .[0].state else "unknown" end' 2>/dev/null)
    machine_region=$(echo "$machine_info" | jq -r 'if .[0].region then .[0].region else "unknown" end' 2>/dev/null)
    cpu_kind=$(echo "$machine_info" | jq -r 'if .[0].config.guest.cpu_kind then .[0].config.guest.cpu_kind else "shared" end' 2>/dev/null)
    cpus=$(echo "$machine_info" | jq -r 'if .[0].config.guest.cpus then .[0].config.guest.cpus else 1 end' 2>/dev/null)
    memory_mb=$(echo "$machine_info" | jq -r 'if .[0].config.guest.memory_mb then .[0].config.guest.memory_mb else 256 end' 2>/dev/null)
    machine_created=$(echo "$machine_info" | jq -r 'if .[0].created_at then .[0].created_at else "unknown" end' 2>/dev/null)

    # Ensure all variables have values (fallback if jq fails)
    machine_id=${machine_id:-"unknown"}
    machine_name=${machine_name:-"unknown"}
    machine_state=${machine_state:-"unknown"}
    machine_region=${machine_region:-"unknown"}
    cpu_kind=${cpu_kind:-"shared"}
    cpus=${cpus:-"1"}
    memory_mb=${memory_mb:-"256"}
    machine_created=${machine_created:-"unknown"}

    # Return pipe-delimited format
    echo "${machine_id}|${machine_name}|${machine_state}|${machine_region}|${cpu_kind}|${cpus}|${memory_mb}|${machine_created}"
}

# Function to get volume information (returns pipe-delimited format)
get_volume_info() {
    local app_name="$1"

    local volume_info
    if ! volume_info=$(flyctl volumes list -a "$app_name" --json 2>/dev/null); then
        print_error "Failed to get volume information"
        return 1
    fi

    # Check if we have valid JSON and at least one volume
    if ! echo "$volume_info" | jq -e '.[0]' >/dev/null 2>&1; then
        print_error "No volumes found or invalid response"
        return 1
    fi

    local volume_id volume_name volume_size volume_region volume_created

    # Extract values with better error handling
    volume_id=$(echo "$volume_info" | jq -r 'if .[0].id then .[0].id else "unknown" end' 2>/dev/null)
    volume_name=$(echo "$volume_info" | jq -r 'if .[0].name then .[0].name else "unknown" end' 2>/dev/null)
    volume_size=$(echo "$volume_info" | jq -r 'if .[0].size_gb then .[0].size_gb else 10 end' 2>/dev/null)
    volume_region=$(echo "$volume_info" | jq -r 'if .[0].region then .[0].region else "unknown" end' 2>/dev/null)
    volume_created=$(echo "$volume_info" | jq -r 'if .[0].created_at then .[0].created_at else "unknown" end' 2>/dev/null)

    # Ensure all variables have values (fallback if jq fails)
    volume_id=${volume_id:-"unknown"}
    volume_name=${volume_name:-"unknown"}
    volume_size=${volume_size:-"10"}
    volume_region=${volume_region:-"unknown"}
    volume_created=${volume_created:-"unknown"}

    # Return pipe-delimited format
    echo "${volume_id}|${volume_name}|${volume_size}|${volume_region}|${volume_created}"
}

# Function to parse pipe-delimited machine info
parse_machine_info() {
    local machine_info="$1"
    local field="$2"

    case "$field" in
        "id"|1) echo "$machine_info" | cut -d'|' -f1 ;;
        "name"|2) echo "$machine_info" | cut -d'|' -f2 ;;
        "state"|3) echo "$machine_info" | cut -d'|' -f3 ;;
        "region"|4) echo "$machine_info" | cut -d'|' -f4 ;;
        "cpu_kind"|5) echo "$machine_info" | cut -d'|' -f5 ;;
        "cpus"|6) echo "$machine_info" | cut -d'|' -f6 ;;
        "memory_mb"|7) echo "$machine_info" | cut -d'|' -f7 ;;
        "created"|8) echo "$machine_info" | cut -d'|' -f8 ;;
        *) echo "unknown" ;;
    esac
}

# Function to parse pipe-delimited volume info
parse_volume_info() {
    local volume_info="$1"
    local field="$2"

    case "$field" in
        "id"|1) echo "$volume_info" | cut -d'|' -f1 ;;
        "name"|2) echo "$volume_info" | cut -d'|' -f2 ;;
        "size"|3) echo "$volume_info" | cut -d'|' -f3 ;;
        "region"|4) echo "$volume_info" | cut -d'|' -f4 ;;
        "created"|5) echo "$volume_info" | cut -d'|' -f5 ;;
        *) echo "unknown" ;;
    esac
}

# Function to format VM size display
format_vm_size() {
    local cpu_kind="$1"
    local cpus="$2"
    local memory_mb="$3"

    if [[ "$cpu_kind" == "performance" ]]; then
        echo "Performance ${cpus}vCPU / ${memory_mb}MB"
    else
        echo "Shared ${cpus}vCPU / ${memory_mb}MB"
    fi
}

# Function to calculate cost per hour
calculate_hourly_cost() {
    local cpu_kind="$1"
    local cpus="$2"
    local memory_mb="$3"

    if [[ "$cpu_kind" == "performance" ]]; then
        # Performance CPUs: $0.035/vCPU/hour + $0.005/GB/hour
        local cpu_component=$(echo "scale=4; $cpus * 0.035" | bc 2>/dev/null || echo "0.035")
        local memory_gb=$(echo "scale=2; $memory_mb / 1024" | bc 2>/dev/null || echo "0.25")
        local memory_component=$(echo "scale=4; $memory_gb * 0.005" | bc 2>/dev/null || echo "0.00125")
        echo "scale=4; $cpu_component + $memory_component" | bc 2>/dev/null || echo "0.03625"
    else
        # Shared CPUs: based on memory size
        if [[ $memory_mb -le 256 ]]; then
            echo "0.0067"
        elif [[ $memory_mb -le 512 ]]; then
            echo "0.0134"
        elif [[ $memory_mb -le 1024 ]]; then
            echo "0.0268"
        elif [[ $memory_mb -le 2048 ]]; then
            echo "0.0536"
        elif [[ $memory_mb -le 4096 ]]; then
            echo "0.1072"
        elif [[ $memory_mb -le 8192 ]]; then
            echo "0.2144"
        else
            echo "0.4288"  # 16GB
        fi
    fi
}

# Function to calculate volume cost per month
calculate_volume_cost() {
    local volume_size="$1"
    echo "scale=2; $volume_size * 0.15" | bc 2>/dev/null || echo "1.50"
}

# Export all functions so they're available to subshells
export -f print_status print_success print_warning print_error print_header print_metric print_debug
export -f command_exists get_timestamp get_backup_timestamp check_flyctl check_prerequisites
export -f validate_app_name check_app_exists setup_remote_vars confirm_action
export -f parse_common_args show_common_usage get_machine_info get_volume_info
export -f parse_machine_info parse_volume_info format_vm_size
export -f calculate_hourly_cost calculate_volume_cost