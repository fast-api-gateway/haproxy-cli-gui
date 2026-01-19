#!/bin/bash
# Module: validator.sh
# Purpose: Validate HAProxy configuration syntax and semantics

# Validate configuration file using HAProxy
# Args: $1 = config file path
# Returns: 0 on success, 1 on failure
validate_config_file() {
    local config_file="$1"
    local output
    local result

    if [[ -z "$config_file" ]]; then
        log_error "validate_config_file: No config file specified"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "validate_config_file: Config file not found: $config_file"
        return 1
    fi

    # Check if haproxy command is available
    if ! command_exists "haproxy"; then
        log_warn "HAProxy command not found, skipping validation"
        return 0  # Don't fail if haproxy not installed
    fi

    # Run HAProxy validation
    log_info "Validating configuration with HAProxy..."
    output=$(haproxy -c -f "$config_file" 2>&1)
    result=$?

    if [[ $result -eq 0 ]]; then
        log_info "Configuration validation PASSED"
        return 0
    else
        log_error "Configuration validation FAILED:"
        echo "$output" >&2
        return 1
    fi
}

# Validate bind address format
# Args: $1 = bind address
# Returns: 0 if valid, 1 if invalid
validate_bind_address() {
    local bind="$1"

    if [[ -z "$bind" ]]; then
        return 1
    fi

    # Check basic bind format
    if is_valid_bind_address "$bind"; then
        return 0
    fi

    # Check for SSL bind
    if [[ "$bind" =~ ^([^:]+:[0-9]+)[[:space:]]+ssl ]]; then
        if is_valid_bind_address "${BASH_REMATCH[1]}"; then
            return 0
        fi
    fi

    return 1
}

# Validate server line format
# Args: $1 = server line
# Returns: 0 if valid, 1 if invalid
validate_server_line() {
    local server_line="$1"
    local server_name
    local server_address

    if [[ -z "$server_line" ]]; then
        return 1
    fi

    # Basic format: server name address:port [options]
    if [[ "$server_line" =~ ^([a-zA-Z0-9_-]+)[[:space:]]+([^:]+):([0-9]+) ]]; then
        server_name="${BASH_REMATCH[1]}"
        server_address="${BASH_REMATCH[2]}"
        local port="${BASH_REMATCH[3]}"

        # Validate server name
        if ! is_valid_server_name "$server_name"; then
            return 1
        fi

        # Validate address
        if ! is_valid_ip "$server_address"; then
            # Could be hostname, allow it
            if [[ ! "$server_address" =~ ^[a-zA-Z0-9.-]+$ ]]; then
                return 1
            fi
        fi

        # Validate port
        if ! is_valid_port "$port"; then
            return 1
        fi

        return 0
    fi

    return 1
}

# Validate ACL expression format
# Args: $1 = ACL line
# Returns: 0 if valid, 1 if invalid
validate_acl_expression() {
    local acl_line="$1"

    if [[ -z "$acl_line" ]]; then
        return 1
    fi

    # Basic format: acl_name criterion [flags] [value]
    if [[ "$acl_line" =~ ^([a-zA-Z0-9_-]+)[[:space:]]+([a-zA-Z0-9_-]+) ]]; then
        return 0
    fi

    return 1
}

# Validate timeout value
# Args: $1 = timeout value
# Returns: 0 if valid, 1 if invalid
validate_timeout_value() {
    is_valid_timeout "$1"
}

# Validate section references (check if referenced backends exist)
# Args: $1 = section name
# Returns: 0 if valid, 1 if invalid
validate_section_references() {
    local section="$1"

    if [[ ! "$section" =~ ^frontend: ]]; then
        return 0  # Only validate frontends
    fi

    # Check default_backend
    local default_backend
    default_backend=$(get_directive "$section" "default_backend")

    if [[ -n "$default_backend" ]]; then
        if ! section_exists "backend:${default_backend}"; then
            log_warn "Frontend $section references non-existent backend: $default_backend"
            return 1
        fi
    fi

    # Check use_backend directives
    local use_backends
    use_backends=$(get_array_directive "$section" "use_backend")

    while IFS= read -r use_backend_line; do
        if [[ -n "$use_backend_line" ]]; then
            # Extract backend name from "use_backend backend_name if condition"
            if [[ "$use_backend_line" =~ ^([a-zA-Z0-9_-]+) ]]; then
                local backend_name="${BASH_REMATCH[1]}"
                if ! section_exists "backend:${backend_name}"; then
                    log_warn "Frontend $section references non-existent backend: $backend_name"
                    return 1
                fi
            fi
        fi
    done <<< "$use_backends"

    return 0
}

# Validate full loaded configuration
# Returns: 0 if valid, 1 if invalid
validate_loaded_config() {
    local errors=0

    if ! is_config_loaded; then
        log_error "No configuration loaded"
        return 1
    fi

    log_info "Validating loaded configuration..."

    # Validate section references
    for section in "${SECTION_LIST[@]}"; do
        if [[ "$section" =~ ^frontend: ]]; then
            if ! validate_section_references "$section"; then
                ((errors++))
            fi
        fi
    done

    if [[ $errors -gt 0 ]]; then
        log_error "Configuration validation found $errors error(s)"
        return 1
    fi

    log_info "Loaded configuration validation passed"
    return 0
}

# Check for common configuration issues
# Returns: 0 if ok, 1 if issues found
check_config_warnings() {
    local warnings=0

    if ! is_config_loaded; then
        return 0
    fi

    log_info "Checking for common configuration issues..."

    # Check if there are any frontends
    local frontend_count
    frontend_count=$(get_sections "frontend" | wc -w)

    if [[ $frontend_count -eq 0 ]]; then
        log_warn "No frontends defined in configuration"
        ((warnings++))
    fi

    # Check if there are any backends
    local backend_count
    backend_count=$(get_sections "backend" | wc -w)

    if [[ $backend_count -eq 0 ]] && [[ $frontend_count -gt 0 ]]; then
        log_warn "Frontends defined but no backends"
        ((warnings++))
    fi

    # Check for backends with no servers
    for section in $(get_sections "backend"); do
        local servers
        servers=$(get_array_directive "$section" "server")
        if [[ -z "$servers" ]]; then
            log_warn "Backend $section has no servers defined"
            ((warnings++))
        fi
    done

    if [[ $warnings -gt 0 ]]; then
        log_info "Found $warnings warning(s) in configuration"
    else
        log_info "No configuration warnings"
    fi

    return 0
}

# Export functions
export -f validate_config_file validate_bind_address validate_server_line
export -f validate_acl_expression validate_timeout_value validate_section_references
export -f validate_loaded_config check_config_warnings

log_debug "Validator module loaded"
