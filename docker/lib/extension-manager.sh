#!/bin/bash
# extension-manager.sh - Manage extension scripts activation and deactivation
# This script provides comprehensive management of extension scripts in the extensions.d directory

# Determine script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if we're in the repository or on the VM
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    # In repository
    source "$SCRIPT_DIR/common.sh"
    EXTENSIONS_BASE="$SCRIPT_DIR/extensions.d"
elif [[ -f "/workspace/scripts/lib/common.sh" ]]; then
    # On VM
    source "/workspace/scripts/lib/common.sh"
    EXTENSIONS_BASE="/workspace/scripts/extensions.d"
else
    # Fallback - define minimal needed functions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'

    print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
    print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
    print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
    print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

    EXTENSIONS_BASE="./extensions.d"
fi

# Function to extract extension name from filename
get_extension_name() {
    local filename="$1"
    local base=$(basename "$filename" .sh.example)
    # Remove leading numbers and dash (e.g., "10-rust" -> "rust")
    echo "$base" | sed 's/^[0-9]*-//'
}

# Function to check if an extension is activated
is_activated() {
    local example_file="$1"
    local activated_file="${example_file%.example}"
    [[ -f "$activated_file" ]]
}

# Function to check if an extension is protected (01-04 prefixes)
is_protected_extension() {
    local filename="$1"
    local base=$(basename "$filename" .sh.example)
    base=$(basename "$base" .sh)

    # Check if filename starts with 01, 02, 03, or 04
    if [[ "$base" =~ ^0[1-4]- ]]; then
        return 0  # Protected
    fi
    return 1  # Not protected
}

# Function to check if a file has been modified from its example
file_has_been_modified() {
    local activated_file="$1"
    local example_file="${activated_file}.example"

    # If example doesn't exist, can't compare
    [[ ! -f "$example_file" ]] && return 0

    # Use checksum to compare files
    if command -v md5sum >/dev/null 2>&1; then
        local sum1=$(md5sum "$activated_file" 2>/dev/null | cut -d' ' -f1)
        local sum2=$(md5sum "$example_file" 2>/dev/null | cut -d' ' -f1)
    elif command -v md5 >/dev/null 2>&1; then
        local sum1=$(md5 -q "$activated_file" 2>/dev/null)
        local sum2=$(md5 -q "$example_file" 2>/dev/null)
    else
        # Fallback to byte comparison if no checksum tool
        if ! cmp -s "$activated_file" "$example_file"; then
            return 0  # Modified
        fi
        return 1  # Not modified
    fi

    [[ "$sum1" != "$sum2" ]]
}

# Function to create a backup of a file
create_backup() {
    local file="$1"
    local backup_file="${file}.backup"

    if cp "$file" "$backup_file"; then
        print_success "Backup created: $(basename "$backup_file")"
        return 0
    else
        print_error "Failed to create backup"
        return 1
    fi
}

# Function to list all extensions
list_extensions() {
    print_status "Available extensions in $EXTENSIONS_BASE:"
    echo ""

    local found_any=false

    # Check if directory exists
    if [[ ! -d "$EXTENSIONS_BASE" ]]; then
        print_error "Extensions directory not found: $EXTENSIONS_BASE"
        return 1
    fi

    # Iterate through all .example files
    for example_file in "$EXTENSIONS_BASE"/*.sh.example; do
        # Skip if no files match
        [[ ! -f "$example_file" ]] && continue

        found_any=true
        local filename=$(basename "$example_file")
        local name=$(get_extension_name "$filename")
        local base_filename="${filename%.example}"

        # Check protection status
        local protected_marker=""
        if is_protected_extension "$base_filename"; then
            protected_marker=" ${CYAN}[PROTECTED]${NC}"
        fi

        if is_activated "$example_file"; then
            echo -e "  ${GREEN}✓${NC} $name ($base_filename) - ${GREEN}activated${NC}${protected_marker}"
        else
            echo -e "  ${YELLOW}○${NC} $name ($filename) - ${YELLOW}not activated${NC}${protected_marker}"
        fi
    done

    if [[ "$found_any" == "false" ]]; then
        print_warning "No extension examples found in $EXTENSIONS_BASE"
        return 1
    fi

    echo ""
    print_status "Use 'extension-manager activate <name>' to activate an extension"
    print_status "Use 'extension-manager deactivate <name>' to deactivate an extension"
    print_status "Use 'extension-manager activate-all' to activate all extensions"
    print_status "Use 'extension-manager deactivate-all' to deactivate all non-protected extensions"
}

# Function to activate a single extension
activate_extension() {
    local extension_name="$1"
    local found=false
    local activated=false

    # Search for matching extension
    for example_file in "$EXTENSIONS_BASE"/*.sh.example; do
        [[ ! -f "$example_file" ]] && continue

        local name=$(get_extension_name "$(basename "$example_file")")

        if [[ "$name" == "$extension_name" ]]; then
            found=true
            local activated_file="${example_file%.example}"
            local filename=$(basename "$activated_file")

            # Check if already activated
            if [[ -f "$activated_file" ]]; then
                print_warning "Extension '$extension_name' ($filename) is already activated"
                return 1
            fi

            # Copy and make executable
            print_status "Activating extension '$extension_name' ($filename)..."

            if cp "$example_file" "$activated_file"; then
                chmod +x "$activated_file"
                print_success "Extension '$extension_name' activated: $filename"
                activated=true
            else
                print_error "Failed to activate extension '$extension_name'"
                return 1
            fi

            break
        fi
    done

    if [[ "$found" == "false" ]]; then
        print_error "Extension '$extension_name' not found"
        echo "Available extensions:"
        for example_file in "$EXTENSIONS_BASE"/*.sh.example; do
            [[ -f "$example_file" ]] && echo "  - $(get_extension_name "$(basename "$example_file")")"
        done
        return 1
    fi

    return 0
}

# Function to activate all extensions
activate_all_extensions() {
    print_status "Activating all available extensions..."
    echo ""

    local activated_count=0
    local skipped_count=0
    local failed_count=0

    for example_file in "$EXTENSIONS_BASE"/*.sh.example; do
        [[ ! -f "$example_file" ]] && continue

        local activated_file="${example_file%.example}"
        local filename=$(basename "$activated_file")
        local name=$(get_extension_name "$filename")

        # Check if already activated
        if [[ -f "$activated_file" ]]; then
            print_warning "Skipping '$name' ($filename) - already activated"
            ((skipped_count++))
            continue
        fi

        # Copy and make executable
        if cp "$example_file" "$activated_file"; then
            chmod +x "$activated_file"
            print_success "Activated '$name' ($filename)"
            ((activated_count++))
        else
            print_error "Failed to activate '$name' ($filename)"
            ((failed_count++))
        fi
    done

    echo ""
    print_status "Summary:"
    [[ $activated_count -gt 0 ]] && print_success "  Activated: $activated_count"
    [[ $skipped_count -gt 0 ]] && print_warning "  Skipped (already active): $skipped_count"
    [[ $failed_count -gt 0 ]] && print_error "  Failed: $failed_count"

    [[ $failed_count -eq 0 ]] && return 0 || return 1
}

# Function to deactivate a single extension
deactivate_extension() {
    local extension_name="$1"
    local backup_flag="${2:-}"
    local yes_flag="${3:-}"
    local found=false

    # Search for matching activated extension
    for example_file in "$EXTENSIONS_BASE"/*.sh.example; do
        [[ ! -f "$example_file" ]] && continue

        local name=$(get_extension_name "$(basename "$example_file")")

        if [[ "$name" == "$extension_name" ]]; then
            found=true
            local activated_file="${example_file%.example}"
            local filename=$(basename "$activated_file")

            # Check if extension is protected
            if is_protected_extension "$filename"; then
                print_error "Cannot deactivate protected extension '$extension_name' ($filename)"
                print_warning "Extensions 01-04 are core system components and cannot be deactivated"
                return 1
            fi

            # Check if extension is activated
            if [[ ! -f "$activated_file" ]]; then
                print_warning "Extension '$extension_name' ($filename) is not activated"
                return 1
            fi

            # Check if file has been modified
            local modified=false
            if file_has_been_modified "$activated_file"; then
                modified=true
                print_warning "Extension '$extension_name' has been modified from the original"
            fi

            # Confirm deactivation if not using --yes flag
            if [[ "$yes_flag" != "--yes" ]]; then
                echo -n "Are you sure you want to deactivate '$extension_name'? (y/N): "
                read -r response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    print_status "Deactivation cancelled"
                    return 1
                fi
            fi

            # Create backup if requested or if file was modified
            if [[ "$backup_flag" == "--backup" ]] || [[ "$modified" == "true" ]]; then
                create_backup "$activated_file"
            fi

            # Remove the activated file
            if rm "$activated_file"; then
                print_success "Extension '$extension_name' deactivated"
            else
                print_error "Failed to deactivate extension '$extension_name'"
                return 1
            fi

            break
        fi
    done

    if [[ "$found" == "false" ]]; then
        print_error "Extension '$extension_name' not found"
        echo "Available extensions:"
        for example_file in "$EXTENSIONS_BASE"/*.sh.example; do
            [[ -f "$example_file" ]] && echo "  - $(get_extension_name "$(basename "$example_file")")"
        done
        return 1
    fi

    return 0
}

# Function to deactivate all extensions
deactivate_all_extensions() {
    local backup_flag="${1:-}"
    local yes_flag="${2:-}"

    print_status "Deactivating all non-protected extensions..."
    echo ""

    # Confirm deactivation if not using --yes flag
    if [[ "$yes_flag" != "--yes" ]]; then
        echo -n "Are you sure you want to deactivate all non-protected extensions? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_status "Deactivation cancelled"
            return 1
        fi
    fi

    local deactivated_count=0
    local skipped_count=0
    local protected_count=0
    local failed_count=0

    for activated_file in "$EXTENSIONS_BASE"/*.sh; do
        [[ ! -f "$activated_file" ]] && continue

        local filename=$(basename "$activated_file")
        local name=$(get_extension_name "$filename")

        # Check if extension is protected
        if is_protected_extension "$filename"; then
            print_warning "Skipping protected extension '$name' ($filename)"
            ((protected_count++))
            continue
        fi

        # Check if corresponding .example exists
        local example_file="${activated_file}.example"
        if [[ ! -f "$example_file" ]]; then
            print_warning "Skipping '$name' ($filename) - no example file found"
            ((skipped_count++))
            continue
        fi

        # Check if file has been modified
        if file_has_been_modified "$activated_file"; then
            print_warning "Extension '$name' has been modified from the original"
            if [[ "$backup_flag" == "--backup" ]]; then
                create_backup "$activated_file"
            fi
        fi

        # Remove the activated file
        if rm "$activated_file"; then
            print_success "Deactivated '$name' ($filename)"
            ((deactivated_count++))
        else
            print_error "Failed to deactivate '$name' ($filename)"
            ((failed_count++))
        fi
    done

    echo ""
    print_status "Summary:"
    [[ $deactivated_count -gt 0 ]] && print_success "  Deactivated: $deactivated_count"
    [[ $protected_count -gt 0 ]] && print_warning "  Protected (skipped): $protected_count"
    [[ $skipped_count -gt 0 ]] && print_warning "  Skipped (no example): $skipped_count"
    [[ $failed_count -gt 0 ]] && print_error "  Failed: $failed_count"

    [[ $failed_count -eq 0 ]] && return 0 || return 1
}

# Function to show help
show_help() {
    cat << EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Manage activation of extension scripts in the extensions.d directory.

Commands:
  list                     List all available extensions and their status
  activate <name>          Activate a specific extension by name
  activate-all             Activate all available extensions
  deactivate <name>        Deactivate a specific extension by name
  deactivate-all           Deactivate all non-protected extensions
  help                     Show this help message

Options:
  --backup                 Create backup before deactivation (automatic for modified files)
  --yes                    Skip confirmation prompts

Examples:
  $(basename "$0") list                         # Show all extensions
  $(basename "$0") activate rust                # Activate the Rust extension
  $(basename "$0") activate-all                 # Activate all extensions
  $(basename "$0") deactivate python            # Deactivate Python extension
  $(basename "$0") deactivate python --backup   # Deactivate with backup
  $(basename "$0") deactivate-all --yes         # Deactivate all without prompts

Extensions are identified by their base name without the number prefix.
For example, '10-rust.sh.example' is referred to as 'rust'.

Protected Extensions:
  Extensions 01-04 are core system components and cannot be deactivated.

Note: Activated extensions will be executed during VM configuration.
EOF
}

# Main script logic
main() {
    local command="${1:-list}"
    shift || true

    case "$command" in
        list)
            list_extensions
            ;;
        activate)
            if [[ -z "$1" ]]; then
                print_error "Extension name required"
                echo "Usage: extension-manager activate <extension-name>"
                exit 1
            fi
            activate_extension "$1"
            ;;
        activate-all)
            activate_all_extensions
            ;;
        deactivate)
            if [[ -z "$1" ]]; then
                print_error "Extension name required"
                echo "Usage: extension-manager deactivate <extension-name> [--backup] [--yes]"
                exit 1
            fi
            local extension_name="$1"
            local backup_flag=""
            local yes_flag=""
            shift
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --backup) backup_flag="--backup" ;;
                    --yes) yes_flag="--yes" ;;
                    *) print_warning "Unknown option: $1" ;;
                esac
                shift
            done
            deactivate_extension "$extension_name" "$backup_flag" "$yes_flag"
            ;;
        deactivate-all)
            local backup_flag=""
            local yes_flag=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --backup) backup_flag="--backup" ;;
                    --yes) yes_flag="--yes" ;;
                    *) print_warning "Unknown option: $1" ;;
                esac
                shift
            done
            deactivate_all_extensions "$backup_flag" "$yes_flag"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"