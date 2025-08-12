#!/bin/bash
# cost-monitor.sh - Monitor and analyze Fly.io costs for Claude development environment
# This script runs on your LOCAL machine to track VM usage and costs

set -e

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/fly-common.sh"

# Configuration
APP_NAME="${APP_NAME:-$DEFAULT_APP_NAME}"
HISTORY_FILE="$HOME/.claude_cost_history"

# Function to calculate costs
calculate_costs() {
    local cpu_kind="$1"
    local cpus="$2"
    local memory_mb="$3"
    local volume_size="$4"
    local hours_running="$5"

    # Use shared library functions
    local cpu_cost_per_hour=$(calculate_hourly_cost "$cpu_kind" "$cpus" "$memory_mb")
    local volume_cost_per_month=$(calculate_volume_cost "$volume_size")
    local compute_cost=$(echo "scale=4; $hours_running * $cpu_cost_per_hour" | bc 2>/dev/null || echo "0.0000")

    echo "$compute_cost|$volume_cost_per_month|$cpu_cost_per_hour"
}

# Functions use shared libraries directly
get_vm_info() {
    get_machine_info "$APP_NAME"
}

get_volume_data() {
    get_volume_info "$APP_NAME"
}

# Function to estimate monthly hours
estimate_monthly_hours() {
    local current_state="$1"

    # Try to read from history file
    if [[ -f "$HISTORY_FILE" ]]; then
        # Count entries from this month
        local current_month
        current_month=$(date +"%Y-%m")
        local running_entries
        running_entries=$(grep "^$current_month" "$HISTORY_FILE" | grep "started" | wc -l || echo "0")
        local total_entries
        total_entries=$(grep "^$current_month" "$HISTORY_FILE" | wc -l || echo "0")

        if [[ $total_entries -gt 0 ]]; then
            local running_ratio
            running_ratio=$(echo "scale=2; $running_entries / $total_entries" | bc 2>/dev/null || echo "0.5")
            local hours_in_month
            hours_in_month=$(echo "scale=0; $(date +%d) * 24" | bc 2>/dev/null || echo "720")
            local estimated_hours
            estimated_hours=$(echo "scale=1; $hours_in_month * $running_ratio" | bc 2>/dev/null || echo "360")
            echo "$estimated_hours"
            return
        fi
    fi

    # Fallback estimates based on current state
    case "$current_state" in
        "started")
            echo "360"  # Assume 50% uptime
            ;;
        "stopped")
            echo "120"  # Assume 20% uptime
            ;;
        *)
            echo "240"  # Assume 33% uptime
            ;;
    esac
}

# Function to log current status
log_status() {
    local vm_info="$1"
    local timestamp
    timestamp=$(get_timestamp)
    local machine_state
    # Extract state from pipe-delimited format
    machine_state=$(echo "$vm_info" | cut -d'|' -f3)

    # Append to history file
    echo "$timestamp $machine_state" >> "$HISTORY_FILE"

    # Keep only last 1000 entries
    if [[ -f "$HISTORY_FILE" ]]; then
        tail -1000 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    fi
}

# Function to show current status
show_current_status() {
    print_header "📊 Current VM Status"
    print_header "===================="

    local vm_info
    if ! vm_info=$(get_vm_info); then
        return 1
    fi

    local volume_info
    if ! volume_info=$(get_volume_data); then
        return 1
    fi

    # Parse VM info (pipe-delimited)
    local machine_id machine_name machine_state machine_region cpu_kind cpus memory_mb machine_created
    IFS='|' read -r machine_id machine_name machine_state machine_region cpu_kind cpus memory_mb machine_created <<< "$vm_info"

    # Parse volume info (pipe-delimited)
    local volume_id volume_name volume_size volume_region volume_created
    IFS='|' read -r volume_id volume_name volume_size volume_region volume_created <<< "$volume_info"

    # Format VM size display
    local vm_size_display=$(format_vm_size "$cpu_kind" "$cpus" "$memory_mb")

    print_metric "App Name:" "$APP_NAME"
    print_metric "Machine Name:" "$machine_name"
    print_metric "Machine ID:" "$machine_id"
    print_metric "State:" "$machine_state"
    print_metric "Region:" "$machine_region"
    print_metric "VM Size:" "$vm_size_display"
    print_metric "Volume Size:" "${volume_size}GB"
    print_metric "Created:" "$(echo "$machine_created" | cut -d'T' -f1 2>/dev/null || echo "$machine_created")"

    # Log current status (just state for history)
    echo "$(get_timestamp) $machine_state" >> "$HISTORY_FILE"

    # Keep only last 1000 entries
    if [[ -f "$HISTORY_FILE" ]]; then
        tail -1000 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
    fi

    echo "$vm_info|$volume_info"
}

# Function to show cost breakdown
show_cost_breakdown() {
    local vm_info="$1"
    local volume_info="$2"

    print_header "💰 Cost Analysis"
    print_header "================"

    # Parse info (pipe-delimited)
    local machine_state cpu_kind cpus memory_mb
    IFS='|' read -r _ _ machine_state _ cpu_kind cpus memory_mb _ <<< "$vm_info"
    local volume_size
    IFS='|' read -r _ _ volume_size _ _ <<< "$volume_info"

    # Estimate monthly hours
    local estimated_monthly_hours
    estimated_monthly_hours=$(estimate_monthly_hours "$machine_state")

    # Calculate costs
    local cost_info
    cost_info=$(calculate_costs "$cpu_kind" "$cpus" "$memory_mb" "$volume_size" "$estimated_monthly_hours")
    local estimated_compute_cost volume_monthly_cost hourly_rate
    IFS='|' read -r estimated_compute_cost volume_monthly_cost hourly_rate <<< "$cost_info"

    # Calculate monthly compute cost properly
    local monthly_compute_cost
    monthly_compute_cost=$(echo "scale=2; $estimated_compute_cost" | bc 2>/dev/null || echo "5.00")

    print_metric "Current State:" "$machine_state"

    if [[ "$machine_state" == "started" ]]; then
        print_metric "Hourly Compute Cost:" "\$$hourly_rate"
        print_metric "Daily Cost (if always on):" "\$$(echo "scale=2; $hourly_rate * 24" | bc 2>/dev/null || echo "0.16")"
    else
        print_metric "Compute Cost:" "\$0.00 (suspended)"
    fi

    print_metric "Volume Cost (monthly):" "\$${volume_monthly_cost}"
    print_metric "Estimated Monthly Total:" "\$$(echo "scale=2; $monthly_compute_cost + $volume_monthly_cost" | bc 2>/dev/null || echo "6.50")"

    echo
    print_status "💡 Cost Optimization Tips:"
    echo "  • Current uptime estimate: ${estimated_monthly_hours}h/month"
    echo "  • Max monthly cost (always on): \$$(echo "scale=2; $hourly_rate * 24 * 30 + $volume_monthly_cost" | bc 2>/dev/null || echo "50.00")"
    echo "  • Savings from auto-suspend: ~$(echo "scale=0; (720 - $estimated_monthly_hours) * 100 / 720" | bc 2>/dev/null || echo "50")%"
    echo "  • Volume costs persist even when VM is suspended"
}

# Function to show usage history
show_usage_history() {
    print_header "📈 Usage History"
    print_header "================"

    if [[ ! -f "$HISTORY_FILE" ]]; then
        print_warning "No usage history available yet"
        print_status "History will be collected as you run this script"
        return
    fi

    # Show last 7 days
    local days_back=7
    print_status "Last $days_back days:"

    for i in $(seq 0 $((days_back-1))); do
        local check_date
        check_date=$(date -d "$i days ago" +"%Y-%m-%d" 2>/dev/null || date -v -"$i"d +"%Y-%m-%d" 2>/dev/null || date +"%Y-%m-%d")

        local day_entries
        day_entries=$(grep "^$check_date" "$HISTORY_FILE" 2>/dev/null || echo "")

        if [[ -n "$day_entries" ]]; then
            local total_entries
            total_entries=$(echo "$day_entries" | wc -l)
            local running_entries
            running_entries=$(echo "$day_entries" | grep "started" | wc -l || echo "0")
            local uptime_percent
            uptime_percent=$(echo "scale=0; $running_entries * 100 / $total_entries" | bc 2>/dev/null || echo "0")

            printf "  %s: %3d%% uptime (%d/%d checks)\n" "$check_date" "$uptime_percent" "$running_entries" "$total_entries"
        else
            printf "  %s: No data\n" "$check_date"
        fi
    done

    # Show total statistics
    echo
    print_status "All-time statistics:"
    local total_entries
    total_entries=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo "0")
    local running_entries
    running_entries=$(grep "started" "$HISTORY_FILE" 2>/dev/null | wc -l || echo "0")
    local overall_uptime
    overall_uptime=$(echo "scale=1; $running_entries * 100 / $total_entries" | bc 2>/dev/null || echo "0")

    print_metric "Total checks:" "$total_entries"
    print_metric "Running checks:" "$running_entries"
    print_metric "Average uptime:" "${overall_uptime}%"
}

# Function to show optimization recommendations
show_recommendations() {
    local vm_info="$1"
    local volume_info="$2"

    print_header "🎯 Optimization Recommendations"
    print_header "==============================="

    # Parse info (pipe-delimited)
    local machine_state cpu_kind cpus memory_mb
    IFS='|' read -r _ _ machine_state _ cpu_kind cpus memory_mb _ <<< "$vm_info"
    local volume_size
    IFS='|' read -r _ _ volume_size _ _ <<< "$volume_info"

    # Analyze usage patterns
    local recommendations=()

    if [[ -f "$HISTORY_FILE" ]]; then
        local total_entries
        total_entries=$(wc -l < "$HISTORY_FILE" 2>/dev/null || echo "0")
        local running_entries
        running_entries=$(grep "started" "$HISTORY_FILE" 2>/dev/null | wc -l || echo "0")

        if [[ $total_entries -gt 10 ]]; then
            local uptime_percent
            uptime_percent=$(echo "scale=0; $running_entries * 100 / $total_entries" | bc || echo "50")

            if [[ $uptime_percent -gt 80 ]]; then
                recommendations+=("Consider a larger VM size for better performance")
                recommendations+=("High usage detected - you're getting good value")
            elif [[ $uptime_percent -lt 20 ]]; then
                recommendations+=("Great job using auto-suspend - excellent cost optimization")
                recommendations+=("Consider smaller volume size if not using full capacity")
            fi
        fi
    fi

    # Volume size recommendations
    if [[ $volume_size -gt 50 ]]; then
        recommendations+=("Large volume detected - ensure you need ${volume_size}GB")
        recommendations+=("Consider archiving old projects to reduce volume size")
    fi

    # VM size recommendations
    if [[ "$cpu_kind" == "performance" ]]; then
        recommendations+=("Using performance CPUs - good for compute-intensive tasks")
        if [[ $cpus -gt 4 ]]; then
            recommendations+=("High CPU count - ensure you need $cpus vCPUs")
        fi
    else
        if [[ $memory_mb -le 512 ]]; then
            recommendations+=("Small memory allocation - upgrade if experiencing slowness")
        elif [[ $memory_mb -ge 8192 ]]; then
            recommendations+=("Large memory allocation - consider downgrading if not fully utilized")
        fi
    fi

    # General recommendations
    recommendations+=("Use 'flyctl machine stop' when done working for the day")
    recommendations+=("Auto-suspend is configured - VM will sleep when idle")
    recommendations+=("Regular backups help reduce volume size over time")
    recommendations+=("Monitor this report weekly to track cost trends")

    if [[ ${#recommendations[@]} -eq 0 ]]; then
        print_success "Configuration looks optimal for typical usage"
    else
        for i in "${!recommendations[@]}"; do
            echo "  $((i+1)). ${recommendations[i]}"
        done
    fi
}

# Function to export data
export_data() {
    local format="$1"
    local output_file="$2"

    print_status "Exporting cost data..."

    case "$format" in
        "csv")
            echo "timestamp,state" > "$output_file"
            if [[ -f "$HISTORY_FILE" ]]; then
                cat "$HISTORY_FILE" | sed 's/ /,/' >> "$output_file"
            fi
            ;;
        "json")
            echo "{ \"history\": [" > "$output_file"
            if [[ -f "$HISTORY_FILE" ]]; then
                local first=true
                while read -r line; do
                    local timestamp state
                    timestamp=$(echo "$line" | cut -d' ' -f1-2)
                    state=$(echo "$line" | awk '{print $3}')

                    if [[ "$first" == true ]]; then
                        first=false
                    else
                        echo "," >> "$output_file"
                    fi

                    echo "    { \"timestamp\": \"$timestamp\", \"state\": \"$state\" }" >> "$output_file"
                done < "$HISTORY_FILE"
            fi
            echo "  ]" >> "$output_file"
            echo "}" >> "$output_file"
            ;;
        *)
            print_error "Unsupported format: $format"
            return 1
            ;;
    esac

    print_success "Data exported to $output_file"
}

# Main function
main() {
    local action="monitor"
    local export_format=""
    local export_file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-name)
                APP_NAME="$2"
                shift 2
                ;;
            --action)
                action="$2"
                shift 2
                ;;
            --export-format)
                export_format="$2"
                shift 2
                ;;
            --export-file)
                export_file="$2"
                shift 2
                ;;
            --help)
                cat << EOF
Usage: $0 [OPTIONS]

Options:
  --app-name NAME         Fly.io app name (default: claude-dev-env)
  --action ACTION         Action to perform (monitor, history, export)
  --export-format FORMAT  Export format (csv, json)
  --export-file FILE      Export output file
  --help                  Show this help message

Actions:
  monitor                 Show current status and cost analysis (default)
  history                 Show usage history and trends
  export                  Export usage data (requires --export-format and --export-file)

Examples:
  $0                                     # Show current cost analysis
  $0 --action history                    # Show usage history
  $0 --action export --export-format csv --export-file usage.csv

Environment Variables:
  APP_NAME                Fly.io application name

EOF
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_status "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    echo "📊 Fly.io Cost Monitor"
    echo "======================"
    echo "App: $APP_NAME"
    echo "Timestamp: $(get_timestamp)"
    echo

    # Check prerequisites
    check_prerequisites "jq" "bc"

    case "$action" in
        monitor)
            # Get VM and volume info directly
            local vm_info
            if ! vm_info=$(get_vm_info); then
                exit 1
            fi

            local volume_info
            if ! volume_info=$(get_volume_data); then
                exit 1
            fi

            # Parse and display current status
            local machine_id machine_name machine_state machine_region cpu_kind cpus memory_mb machine_created
            IFS='|' read -r machine_id machine_name machine_state machine_region cpu_kind cpus memory_mb machine_created <<< "$vm_info"

            local volume_id volume_name volume_size volume_region volume_created
            IFS='|' read -r volume_id volume_name volume_size volume_region volume_created <<< "$volume_info"

            # Format VM size display
            local vm_size_display=$(format_vm_size "$cpu_kind" "$cpus" "$memory_mb")

            print_header "📊 Current VM Status"
            print_header "===================="
            print_metric "App Name:" "$APP_NAME"
            print_metric "Machine Name:" "$machine_name"
            print_metric "Machine ID:" "$machine_id"
            print_metric "State:" "$machine_state"
            print_metric "Region:" "$machine_region"
            print_metric "VM Size:" "$vm_size_display"
            print_metric "Volume Size:" "${volume_size}GB"
            print_metric "Created:" "$(echo "$machine_created" | cut -d'T' -f1 2>/dev/null || echo "$machine_created")"

            # Log status
            echo "$(get_timestamp) $machine_state" >> "$HISTORY_FILE"
            if [[ -f "$HISTORY_FILE" ]]; then
                tail -1000 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
            fi

            echo
            show_cost_breakdown "$vm_info" "$volume_info"
            echo
            show_recommendations "$vm_info" "$volume_info"
            ;;
        history)
            show_usage_history
            ;;
        export)
            if [[ -z "$export_format" ]] || [[ -z "$export_file" ]]; then
                print_error "Export requires --export-format and --export-file"
                exit 1
            fi
            export_data "$export_format" "$export_file"
            ;;
        *)
            print_error "Unknown action: $action"
            print_status "Use --help for available actions"
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi