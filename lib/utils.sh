#!/bin/bash
# Module: utils.sh
# Purpose: Common utility functions and helpers

# Global settings
LOG_FILE="${LOG_FILE:-/var/log/haproxy-gui.log}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"  # DEBUG, INFO, WARN, ERROR
DEBUG="${DEBUG:-0}"
VERBOSE="${VERBOSE:-0}"

# Log levels
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
)

# Get current log level value
get_log_level_value() {
    echo "${LOG_LEVELS[$LOG_LEVEL]:-1}"
}

# Logging functions
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    local level_value="${LOG_LEVELS[$level]:-1}"
    local current_level_value
    current_level_value=$(get_log_level_value)

    # Check if message should be logged based on level
    if [[ $level_value -lt $current_level_value ]]; then
        return 0
    fi

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Output to stderr for visibility
    echo "[$timestamp] [$level] $message" >&2

    # Also log to file if writable
    if [[ -n "$LOG_FILE" ]] && [[ -w "$(dirname "$LOG_FILE" 2>/dev/null)" ]] 2>/dev/null; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null
    fi
}

log_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        log_message "DEBUG" "$@"
    fi
}

log_info() {
    log_message "INFO" "$@"
}

log_warn() {
    log_message "WARN" "$@"
}

log_error() {
    log_message "ERROR" "$@"
}

# Display functions for user interaction
show_success() {
    local message="$1"
    echo "[✓] $message"
    log_info "SUCCESS: $message"
}

show_error() {
    local message="$1"
    echo "[✗] ERROR: $message" >&2
    log_error "$message"
}

show_warning() {
    local message="$1"
    echo "[!] WARNING: $message"
    log_warn "$message"
}

show_info() {
    local message="$1"
    echo "[i] $message"
    log_info "$message"
}

# String manipulation functions
trim() {
    local string="$1"
    # Remove leading whitespace
    string="${string#"${string%%[![:space:]]*}"}"
    # Remove trailing whitespace
    string="${string%"${string##*[![:space:]]}"}"
    echo "$string"
}

to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Escape special characters for safe use in commands
escape_string() {
    local string="$1"
    # Escape single quotes by replacing ' with '\''
    string="${string//\'/\'\\\'\'}"
    echo "$string"
}

# Remove quotes from string
unquote() {
    local string="$1"
    # Remove leading and trailing quotes
    string="${string#\"}"
    string="${string%\"}"
    string="${string#\'}"
    string="${string%\'}"
    echo "$string"
}

# Validation functions

# Validate IPv4 address
is_valid_ipv4() {
    local ip="$1"
    local IFS='.'
    local -a octets=($ip)

    # Check if we have 4 octets
    if [[ ${#octets[@]} -ne 4 ]]; then
        return 1
    fi

    # Check each octet
    for octet in "${octets[@]}"; do
        # Check if octet is a number
        if ! [[ "$octet" =~ ^[0-9]+$ ]]; then
            return 1
        fi
        # Check if octet is in valid range (0-255)
        if [[ $octet -lt 0 ]] || [[ $octet -gt 255 ]]; then
            return 1
        fi
    done

    return 0
}

# Validate IPv6 address (basic check)
is_valid_ipv6() {
    local ip="$1"

    # Basic IPv6 pattern check
    if [[ "$ip" =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]]; then
        return 0
    fi

    # Check for :: compression
    if [[ "$ip" =~ :: ]]; then
        return 0
    fi

    return 1
}

# Validate IP address (IPv4 or IPv6 or wildcard)
is_valid_ip() {
    local ip="$1"

    # Check for wildcard
    if [[ "$ip" == "*" ]]; then
        return 0
    fi

    # Check for IPv4
    if is_valid_ipv4 "$ip"; then
        return 0
    fi

    # Check for IPv6
    if is_valid_ipv6 "$ip"; then
        return 0
    fi

    return 1
}

# Validate port number
is_valid_port() {
    local port="$1"

    # Check if port is a number
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    # Check if port is in valid range (1-65535)
    if [[ $port -lt 1 ]] || [[ $port -gt 65535 ]]; then
        return 1
    fi

    return 0
}

# Validate bind address (IP:port or *:port)
is_valid_bind_address() {
    local bind="$1"
    local ip
    local port

    # Extract IP and port
    if [[ "$bind" =~ ^(.+):([0-9]+)$ ]]; then
        ip="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[2]}"

        # Validate IP and port
        if is_valid_ip "$ip" && is_valid_port "$port"; then
            return 0
        fi
    fi

    return 1
}

# Validate timeout value (number with optional unit: ms, s, m, h, d)
is_valid_timeout() {
    local timeout="$1"

    if [[ "$timeout" =~ ^[0-9]+(ms|s|m|h|d)?$ ]]; then
        return 0
    fi

    return 1
}

# Validate section name (alphanumeric, underscore, dash)
is_valid_section_name() {
    local name="$1"

    if [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 0
    fi

    return 1
}

# Validate server name
is_valid_server_name() {
    is_valid_section_name "$1"
}

# Validate ACL name
is_valid_acl_name() {
    is_valid_section_name "$1"
}

# File operations

# Ensure directory exists
ensure_directory() {
    local dir="$1"

    if [[ -z "$dir" ]]; then
        log_error "ensure_directory: No directory specified"
        return 1
    fi

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null || {
            log_error "Failed to create directory: $dir"
            return 1
        }
    fi

    return 0
}

# Safe file write (write to temp file, then move)
safe_write() {
    local target_file="$1"
    local content="$2"
    local temp_file="${target_file}.tmp.$$"

    # Write to temp file
    echo "$content" > "$temp_file" 2>/dev/null || {
        log_error "Failed to write temp file: $temp_file"
        rm -f "$temp_file" 2>/dev/null
        return 1
    }

    # Atomic move
    mv -f "$temp_file" "$target_file" 2>/dev/null || {
        log_error "Failed to move temp file to target: $target_file"
        rm -f "$temp_file" 2>/dev/null
        return 1
    }

    return 0
}

# Get file checksum
get_file_hash() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    # Use sha256sum if available, otherwise md5sum
    if command -v sha256sum &>/dev/null; then
        sha256sum "$file" 2>/dev/null | cut -d' ' -f1
    elif command -v md5sum &>/dev/null; then
        md5sum "$file" 2>/dev/null | cut -d' ' -f1
    else
        # Fallback to cksum
        cksum "$file" 2>/dev/null | cut -d' ' -f1
    fi
}

# Check if file has changed
file_has_changed() {
    local file="$1"
    local last_hash="$2"
    local current_hash

    current_hash=$(get_file_hash "$file")

    if [[ "$current_hash" != "$last_hash" ]]; then
        return 0  # File has changed
    fi

    return 1  # File unchanged
}

# Get file modification time
get_file_mtime() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null
}

# System checks

# Check if running as root or with sudo
is_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi
    return 1
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check required dependencies
check_dependencies() {
    local missing=()

    # Required commands
    local required=("bash" "sed" "awk" "grep" "cat")

    for cmd in "${required[@]}"; do
        if ! command_exists "$cmd"; then
            missing+=("$cmd")
        fi
    done

    # Check for dialog or whiptail
    if ! command_exists "dialog" && ! command_exists "whiptail"; then
        missing+=("dialog or whiptail")
    fi

    # Check for HAProxy
    if ! command_exists "haproxy"; then
        missing+=("haproxy")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        show_error "Missing required dependencies: ${missing[*]}"
        return 1
    fi

    return 0
}

# Get preferred dialog command
get_dialog_command() {
    if command_exists "dialog"; then
        echo "dialog"
    elif command_exists "whiptail"; then
        echo "whiptail"
    else
        log_error "Neither dialog nor whiptail found"
        return 1
    fi
}

# Confirmation prompt
confirm_action() {
    local message="$1"
    local response

    read -r -p "$message (y/N): " response
    response=$(to_lower "$response")

    if [[ "$response" == "y" ]] || [[ "$response" == "yes" ]]; then
        return 0
    fi

    return 1
}

# Array utilities

# Check if array contains element
array_contains() {
    local element="$1"
    shift
    local array=("$@")

    for item in "${array[@]}"; do
        if [[ "$item" == "$element" ]]; then
            return 0
        fi
    done

    return 1
}

# Join array elements with delimiter
array_join() {
    local delimiter="$1"
    shift
    local array=("$@")
    local result=""

    for item in "${array[@]}"; do
        if [[ -z "$result" ]]; then
            result="$item"
        else
            result="${result}${delimiter}${item}"
        fi
    done

    echo "$result"
}

# Error handling

# Die with error message
die() {
    local message="$1"
    local exit_code="${2:-1}"

    show_error "$message"
    exit "$exit_code"
}

# Trap handler for cleanup
cleanup_on_exit() {
    local exit_code=$?

    # Perform cleanup tasks
    log_debug "Cleanup on exit (code: $exit_code)"

    # Remove temp files if any
    rm -f /tmp/haproxy-gui.*.tmp 2>/dev/null

    exit $exit_code
}

# Set up trap for cleanup
setup_traps() {
    trap cleanup_on_exit EXIT INT TERM
}

# Performance helpers

# Measure execution time
time_execution() {
    local start_time
    local end_time
    local duration
    local command="$*"

    start_time=$(date +%s%N)

    # Execute command
    eval "$command"
    local result=$?

    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds

    log_debug "Execution time for '$command': ${duration}ms"

    return $result
}

# Color codes for terminal output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'  # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    NC=''
fi

# Export functions
export -f log_message log_debug log_info log_warn log_error
export -f show_success show_error show_warning show_info
export -f trim to_lower to_upper escape_string unquote
export -f is_valid_ipv4 is_valid_ipv6 is_valid_ip is_valid_port
export -f is_valid_bind_address is_valid_timeout is_valid_section_name is_valid_server_name is_valid_acl_name
export -f ensure_directory safe_write get_file_hash file_has_changed get_file_mtime
export -f is_root command_exists check_dependencies get_dialog_command confirm_action
export -f array_contains array_join
export -f die cleanup_on_exit setup_traps time_execution

log_debug "Utilities module loaded"
