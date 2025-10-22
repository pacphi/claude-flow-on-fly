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
export DEFAULT_APP_NAME="sindri-dev-env"
export DEFAULT_REMOTE_USER="developer"
export DEFAULT_REMOTE_PORT="10022"
export DEFAULT_VOLUME_NAME="sindri_data"
export DEFAULT_REGION="sjc"

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
    echo "  --app-name NAME     Fly.io app name (default: sindri-dev-env)"
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

# Function to calculate cost per hour based on current Fly.io pricing (2025)
calculate_hourly_cost() {
    local cpu_kind="$1"
    local cpus="$2"
    local memory_mb="$3"

    if [[ "$cpu_kind" == "performance" ]]; then
        # Performance CPU pricing lookup table (CPU count + memory combination)
        case "${cpus}x${memory_mb}" in
            # 1x performance CPU
            "1x2048") echo "0.0431" ;;
            "1x4096") echo "0.0570" ;;
            "1x8192") echo "0.0847" ;;
            # 2x performance CPU
            "2x4096") echo "0.0861" ;;
            "2x8192") echo "0.1139" ;;
            "2x16384") echo "0.1695" ;;
            # 4x performance CPU
            "4x8192") echo "0.1722" ;;
            "4x16384") echo "0.2278" ;;
            "4x32768") echo "0.3390" ;;
            # 8x performance CPU
            "8x16384") echo "0.3444" ;;
            "8x32768") echo "0.4556" ;;
            "8x65536") echo "0.6780" ;;
            # 16x performance CPU
            "16x32768") echo "0.6889" ;;
            "16x65536") echo "0.9112" ;;
            "16x131072") echo "1.3559" ;;
            *)
                # Fallback formula for unlisted combinations: ~$0.043/vCPU + ~$0.0035/GB
                local cpu_component=$(echo "scale=4; $cpus * 0.043" | bc 2>/dev/null || echo "0.043")
                local memory_gb=$(echo "scale=2; $memory_mb / 1024" | bc 2>/dev/null || echo "2.0")
                local memory_component=$(echo "scale=4; $memory_gb * 0.0035" | bc 2>/dev/null || echo "0.007")
                echo "scale=4; $cpu_component + $memory_component" | bc 2>/dev/null || echo "0.050"
                ;;
        esac
    else
        # Shared CPU pricing lookup table (CPU count + memory combination)
        case "${cpus}x${memory_mb}" in
            # 1x shared CPU
            "1x256") echo "0.0027" ;;
            "1x512") echo "0.0044" ;;
            "1x1024") echo "0.0079" ;;
            "1x2048") echo "0.0149" ;;
            # 2x shared CPU
            "2x512") echo "0.0054" ;;
            "2x1024") echo "0.0089" ;;
            "2x2048") echo "0.0158" ;;
            "2x4096") echo "0.0297" ;;
            # 4x shared CPU
            "4x1024") echo "0.0108" ;;
            "4x2048") echo "0.0177" ;;
            "4x4096") echo "0.0316" ;;
            "4x8192") echo "0.0594" ;;
            # 8x shared CPU
            "8x2048") echo "0.0216" ;;
            "8x4096") echo "0.0355" ;;
            "8x8192") echo "0.0633" ;;
            "8x16384") echo "0.1189" ;;
            *)
                # Fallback calculation for unlisted combinations
                # Base rate per CPU scales roughly: 1x=$0.0027, 2x=$0.0054, 4x=$0.0108, 8x=$0.0216
                # Memory adds cost: estimate ~$0.002/GB
                local base_cpu_rate
                case "$cpus" in
                    1) base_cpu_rate="0.0027" ;;
                    2) base_cpu_rate="0.0054" ;;
                    4) base_cpu_rate="0.0108" ;;
                    8) base_cpu_rate="0.0216" ;;
                    *) base_cpu_rate=$(echo "scale=4; $cpus * 0.0027" | bc 2>/dev/null || echo "0.0027") ;;
                esac
                local memory_gb=$(echo "scale=2; $memory_mb / 1024" | bc 2>/dev/null || echo "0.25")
                local memory_component=$(echo "scale=4; $memory_gb * 0.002" | bc 2>/dev/null || echo "0.0005")
                echo "scale=4; $base_cpu_rate + $memory_component" | bc 2>/dev/null || echo "0.003"
                ;;
        esac
    fi
}

# Function to validate CPU/memory combinations
validate_cpu_memory_combination() {
    local cpu_kind="$1"
    local cpus="$2"
    local memory_mb="$3"

    if [[ "$cpu_kind" == "performance" ]]; then
        # Valid performance CPU combinations
        case "${cpus}x${memory_mb}" in
            "1x2048"|"1x4096"|"1x8192"|"2x4096"|"2x8192"|"2x16384"|"4x8192"|"4x16384"|"4x32768"|"8x16384"|"8x32768"|"8x65536"|"16x32768"|"16x65536"|"16x131072")
                return 0  # Valid combination
                ;;
            *)
                print_warning "Performance CPU combination ${cpus}vCPU/${memory_mb}MB may not be available"
                print_status "Common performance combinations:"
                print_status "  1x: 2GB, 4GB, 8GB"
                print_status "  2x: 4GB, 8GB, 16GB"
                print_status "  4x: 8GB, 16GB, 32GB"
                print_status "  8x: 16GB, 32GB, 64GB"
                print_status "  16x: 32GB, 64GB, 128GB"
                return 1  # Invalid combination
                ;;
        esac
    else
        # Valid shared CPU combinations
        case "${cpus}x${memory_mb}" in
            "1x256"|"1x512"|"1x1024"|"1x2048"|"2x512"|"2x1024"|"2x2048"|"2x4096"|"4x1024"|"4x2048"|"4x4096"|"4x8192"|"8x2048"|"8x4096"|"8x8192"|"8x16384")
                return 0  # Valid combination
                ;;
            *)
                print_warning "Shared CPU combination ${cpus}vCPU/${memory_mb}MB may not be available"
                print_status "Common shared combinations:"
                print_status "  1x: 256MB, 512MB, 1GB, 2GB"
                print_status "  2x: 512MB, 1GB, 2GB, 4GB"
                print_status "  4x: 1GB, 2GB, 4GB, 8GB"
                print_status "  8x: 2GB, 4GB, 8GB, 16GB"
                return 1  # Invalid combination
                ;;
        esac
    fi
}

# Function to suggest valid CPU/memory combinations
suggest_cpu_memory_combinations() {
    local cpu_kind="$1"
    local requested_cpus="$2"
    local requested_memory_mb="$3"

    print_status "Suggested valid ${cpu_kind} CPU combinations:"

    if [[ "$cpu_kind" == "performance" ]]; then
        case "$requested_cpus" in
            1)
                print_status "  1x performance: 2GB ($0.0431/hr, ~$31/mo), 4GB ($0.0570/hr, ~$41/mo), 8GB ($0.0847/hr, ~$61/mo)"
                ;;
            2)
                print_status "  2x performance: 4GB ($0.0861/hr, ~$62/mo), 8GB ($0.1139/hr, ~$82/mo), 16GB ($0.1695/hr, ~$122/mo)"
                ;;
            4)
                print_status "  4x performance: 8GB ($0.1722/hr, ~$124/mo), 16GB ($0.2278/hr, ~$164/mo), 32GB ($0.3390/hr, ~$244/mo)"
                ;;
            8)
                print_status "  8x performance: 16GB ($0.3444/hr, ~$248/mo), 32GB ($0.4556/hr, ~$328/mo), 64GB ($0.6780/hr, ~$488/mo)"
                ;;
            16)
                print_status "  16x performance: 32GB ($0.6889/hr, ~$496/mo), 64GB ($0.9112/hr, ~$656/mo), 128GB ($1.3559/hr, ~$976/mo)"
                ;;
            *)
                print_status "  Valid performance CPU counts: 1, 2, 4, 8, 16"
                print_status "  Performance CPUs require minimum 2GB memory"
                ;;
        esac
    else
        case "$requested_cpus" in
            1)
                print_status "  1x shared: 256MB ($0.0027/hr, ~$2/mo), 512MB ($0.0044/hr, ~$3/mo), 1GB ($0.0079/hr, ~$6/mo), 2GB ($0.0149/hr, ~$11/mo)"
                ;;
            2)
                print_status "  2x shared: 512MB ($0.0054/hr, ~$4/mo), 1GB ($0.0089/hr, ~$6/mo), 2GB ($0.0158/hr, ~$11/mo), 4GB ($0.0297/hr, ~$21/mo)"
                ;;
            4)
                print_status "  4x shared: 1GB ($0.0108/hr, ~$8/mo), 2GB ($0.0177/hr, ~$13/mo), 4GB ($0.0316/hr, ~$23/mo), 8GB ($0.0594/hr, ~$43/mo)"
                ;;
            8)
                print_status "  8x shared: 2GB ($0.0216/hr, ~$16/mo), 4GB ($0.0355/hr, ~$26/mo), 8GB ($0.0633/hr, ~$46/mo), 16GB ($0.1189/hr, ~$86/mo)"
                ;;
            *)
                print_status "  Valid shared CPU counts: 1, 2, 4, 8"
                print_status "  Shared CPUs support 256MB to 16GB memory"
                ;;
        esac
    fi
}

# Function to format cost display with hourly and monthly rates
format_cost_display() {
    local hourly_rate="$1"
    local include_volume="${2:-false}"
    local volume_size="${3:-10}"

    # Calculate monthly cost (720 hours)
    local monthly_compute=$(echo "scale=2; $hourly_rate * 720" | bc 2>/dev/null || echo "0")

    if [[ "$include_volume" == "true" ]]; then
        local volume_monthly=$(calculate_volume_cost "$volume_size")
        local total_monthly=$(echo "scale=2; $monthly_compute + $volume_monthly" | bc 2>/dev/null || echo "0")
        echo "$hourly_rate|$monthly_compute|$volume_monthly|$total_monthly"
    else
        echo "$hourly_rate|$monthly_compute"
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
export -f calculate_hourly_cost calculate_volume_cost validate_cpu_memory_combination suggest_cpu_memory_combinations format_cost_display