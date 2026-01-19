#!/bin/bash
# Module: config-parser.sh
# Purpose: Parse HAProxy configuration files into memory structures

# Global configuration storage
declare -gA CONFIG              # Main config storage: CONFIG[section:directive]=value
declare -gA CONFIG_ARRAYS       # Multi-value directives: CONFIG_ARRAYS[section:directive:index]=value
declare -gA CONFIG_COMMENTS     # Inline comments: CONFIG_COMMENTS[section:directive]=comment
declare -gA CONFIG_ORDER        # Preserve order: CONFIG_ORDER[section]=order_number
declare -ga SECTION_LIST        # Ordered list of sections
declare -g CONFIG_LOADED=0      # Flag indicating if config is loaded
declare -g CONFIG_FILE_HASH=""  # Hash of loaded config file

# Section types
declare -ga SECTION_TYPES=("global" "defaults" "frontend" "backend" "listen")

# Parse HAProxy configuration file
# Args: $1 = config file path
# Returns: 0 on success, 1 on failure
parse_config_file() {
    local config_file="$1"
    local current_section=""
    local current_section_type=""
    local line_number=0
    local section_counter=0

    # Validate input
    if [[ -z "$config_file" ]]; then
        log_error "parse_config_file: No config file specified"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "parse_config_file: Config file not found: $config_file"
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        log_error "parse_config_file: Config file not readable: $config_file"
        return 1
    fi

    log_info "Parsing configuration file: $config_file"

    # Clear existing configuration
    unset CONFIG CONFIG_ARRAYS CONFIG_COMMENTS CONFIG_ORDER SECTION_LIST
    declare -gA CONFIG CONFIG_ARRAYS CONFIG_COMMENTS CONFIG_ORDER
    declare -ga SECTION_LIST

    # Read file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_number++))

        # Trim leading/trailing whitespace
        line=$(trim "$line")

        # Skip empty lines
        if [[ -z "$line" ]]; then
            continue
        fi

        # Skip pure comment lines
        if [[ "$line" =~ ^# ]]; then
            continue
        fi

        # Check if line starts a new section
        if [[ "$line" =~ ^(global|defaults|frontend|backend|listen)([[:space:]]+(.+))?$ ]]; then
            local section_type="${BASH_REMATCH[1]}"
            local section_name="${BASH_REMATCH[3]}"

            # For global and defaults, there's no name
            if [[ "$section_type" == "global" ]] || [[ "$section_type" == "defaults" ]]; then
                current_section="$section_type"
                current_section_type="$section_type"
            else
                # For frontend, backend, listen - name is required
                section_name=$(trim "$section_name")
                if [[ -z "$section_name" ]]; then
                    log_warn "Line $line_number: Section $section_type without name, skipping"
                    continue
                fi
                current_section="${section_type}:${section_name}"
                current_section_type="$section_type"
            fi

            # Add to section list if not already present
            if ! array_contains "$current_section" "${SECTION_LIST[@]}"; then
                SECTION_LIST+=("$current_section")
                CONFIG_ORDER["$current_section"]=$section_counter
                ((section_counter++))
            fi

            log_debug "Found section: $current_section"
            continue
        fi

        # If no current section, skip (should be in a section)
        if [[ -z "$current_section" ]]; then
            log_warn "Line $line_number: Directive outside of section, skipping: $line"
            continue
        fi

        # Parse directive
        parse_directive "$current_section" "$line" "$line_number"

    done < "$config_file"

    # Store config file hash
    CONFIG_FILE_HASH=$(get_file_hash "$config_file")
    CONFIG_LOADED=1

    log_info "Configuration parsed successfully: ${#SECTION_LIST[@]} sections"
    return 0
}

# Parse a single directive line
# Args: $1 = current section
#       $2 = line content
#       $3 = line number (for logging)
parse_directive() {
    local section="$1"
    local line="$2"
    local line_number="$3"
    local directive
    local value
    local comment=""

    # Extract inline comment if present
    if [[ "$line" =~ ^([^#]+)(#.*)$ ]]; then
        line=$(trim "${BASH_REMATCH[1]}")
        comment=$(trim "${BASH_REMATCH[2]}")
    fi

    # Split directive and value
    if [[ "$line" =~ ^([a-zA-Z0-9_-]+)([[:space:]]+(.+))?$ ]]; then
        directive="${BASH_REMATCH[1]}"
        value=$(trim "${BASH_REMATCH[3]}")
    else
        log_warn "Line $line_number: Cannot parse directive: $line"
        return 1
    fi

    # Handle special multi-value directives
    case "$directive" in
        "server"|"bind"|"acl"|"use_backend"|"http-request"|"http-response")
            # These can appear multiple times
            add_array_directive "$section" "$directive" "$value"
            ;;
        *)
            # Single-value directive
            CONFIG["${section}:${directive}"]="$value"
            ;;
    esac

    # Store comment if present
    if [[ -n "$comment" ]]; then
        CONFIG_COMMENTS["${section}:${directive}"]="$comment"
    fi

    log_debug "  Directive: $directive = $value"
    return 0
}

# Add a multi-value directive (server, bind, acl, etc.)
# Args: $1 = section
#       $2 = directive name
#       $3 = value
add_array_directive() {
    local section="$1"
    local directive="$2"
    local value="$3"
    local key="${section}:${directive}"
    local index=0

    # Find next available index
    while [[ -n "${CONFIG_ARRAYS[${key}:${index}]:-}" ]]; do
        ((index++))
    done

    CONFIG_ARRAYS["${key}:${index}"]="$value"
    log_debug "  Array directive: ${key}:${index} = $value"
}

# Get list of all sections
# Args: $1 = section type filter (optional: global, defaults, frontend, backend, listen)
# Returns: space-separated list of sections
get_sections() {
    local type_filter="$1"
    local result=()

    for section in "${SECTION_LIST[@]}"; do
        if [[ -z "$type_filter" ]]; then
            # No filter, return all
            result+=("$section")
        else
            # Filter by type
            if [[ "$section" == "$type_filter" ]] || [[ "$section" =~ ^${type_filter}: ]]; then
                result+=("$section")
            fi
        fi
    done

    echo "${result[@]}"
}

# Get section names for a specific type (frontend, backend, listen)
# Args: $1 = section type
# Returns: space-separated list of section names
get_section_names() {
    local section_type="$1"
    local result=()

    for section in "${SECTION_LIST[@]}"; do
        if [[ "$section" =~ ^${section_type}:(.+)$ ]]; then
            result+=("${BASH_REMATCH[1]}")
        fi
    done

    echo "${result[@]}"
}

# Check if section exists
# Args: $1 = section (e.g., "frontend:http_front" or "global")
# Returns: 0 if exists, 1 if not
section_exists() {
    local section="$1"

    if array_contains "$section" "${SECTION_LIST[@]}"; then
        return 0
    fi

    return 1
}

# Get directive value from section
# Args: $1 = section
#       $2 = directive name
# Returns: directive value or empty string
get_directive() {
    local section="$1"
    local directive="$2"
    local key="${section}:${directive}"

    echo "${CONFIG[$key]}"
}

# Get all values for array directive
# Args: $1 = section
#       $2 = directive name (server, bind, acl, etc.)
# Returns: newline-separated list of values
get_array_directive() {
    local section="$1"
    local directive="$2"
    local key="${section}:${directive}"
    local index=0
    local result=()

    while [[ -n "${CONFIG_ARRAYS[${key}:${index}]:-}" ]]; do
        result+=("${CONFIG_ARRAYS[${key}:${index}]}")
        ((index++))
    done

    # Print each value on a new line
    printf '%s\n' "${result[@]}"
}

# Get all servers in a backend
# Args: $1 = backend section name
# Returns: newline-separated list of server definitions
get_servers() {
    local backend="$1"
    get_array_directive "backend:${backend}" "server"
}

# Get all bind addresses in a frontend
# Args: $1 = frontend section name
# Returns: newline-separated list of bind definitions
get_binds() {
    local frontend="$1"
    get_array_directive "frontend:${frontend}" "bind"
}

# Get all ACLs in a frontend
# Args: $1 = frontend section name
# Returns: newline-separated list of ACL definitions
get_acls() {
    local frontend="$1"
    get_array_directive "frontend:${frontend}" "acl"
}

# Get all directives in a section
# Args: $1 = section
# Returns: newline-separated list of "directive=value"
get_section_directives() {
    local section="$1"
    local results=()

    # Get single-value directives
    for key in "${!CONFIG[@]}"; do
        if [[ "$key" =~ ^${section}:(.+)$ ]]; then
            local directive="${BASH_REMATCH[1]}"
            results+=("${directive}=${CONFIG[$key]}")
        fi
    done

    # Get array directives (show count)
    for key in "${!CONFIG_ARRAYS[@]}"; do
        if [[ "$key" =~ ^${section}:([^:]+):([0-9]+)$ ]]; then
            local directive="${BASH_REMATCH[1]}"
            local value="${CONFIG_ARRAYS[$key]}"
            results+=("${directive}=${value}")
        fi
    done

    printf '%s\n' "${results[@]}" | sort
}

# Display section configuration
# Args: $1 = section
display_section() {
    local section="$1"

    if ! section_exists "$section"; then
        echo "Section not found: $section"
        return 1
    fi

    # Print section header
    if [[ "$section" == "global" ]] || [[ "$section" == "defaults" ]]; then
        echo "$section"
    elif [[ "$section" =~ ^([^:]+):(.+)$ ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    fi

    # Print single-value directives
    for key in "${!CONFIG[@]}"; do
        if [[ "$key" =~ ^${section}:(.+)$ ]]; then
            local directive="${BASH_REMATCH[1]}"
            local value="${CONFIG[$key]}"
            local comment="${CONFIG_COMMENTS[$key]}"

            if [[ -n "$comment" ]]; then
                printf "    %-30s %s\n" "$directive $value" "$comment"
            else
                printf "    %s %s\n" "$directive" "$value"
            fi
        fi
    done

    # Print array directives
    local last_directive=""
    for key in $(printf '%s\n' "${!CONFIG_ARRAYS[@]}" | grep "^${section}:" | sort); do
        if [[ "$key" =~ ^${section}:([^:]+):([0-9]+)$ ]]; then
            local directive="${BASH_REMATCH[1]}"
            local value="${CONFIG_ARRAYS[$key]}"

            # Add blank line between different array directive types
            if [[ -n "$last_directive" ]] && [[ "$last_directive" != "$directive" ]]; then
                echo ""
            fi

            printf "    %s %s\n" "$directive" "$value"
            last_directive="$directive"
        fi
    done

    echo ""
}

# Display full configuration
display_full_config() {
    for section in "${SECTION_LIST[@]}"; do
        display_section "$section"
    done
}

# Check if configuration is loaded
is_config_loaded() {
    if [[ $CONFIG_LOADED -eq 1 ]]; then
        return 0
    fi
    return 1
}

# Reload configuration if file has changed
# Args: $1 = config file path
# Returns: 0 if reloaded or unchanged, 1 on error
reload_if_changed() {
    local config_file="$1"
    local current_hash

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    current_hash=$(get_file_hash "$config_file")

    if [[ "$current_hash" != "$CONFIG_FILE_HASH" ]]; then
        log_info "Config file has changed, reloading..."
        parse_config_file "$config_file"
        return $?
    fi

    log_debug "Config file unchanged, using cached version"
    return 0
}

# Get configuration statistics
get_config_stats() {
    local frontend_count=0
    local backend_count=0
    local listen_count=0
    local server_count=0

    # Count sections
    for section in "${SECTION_LIST[@]}"; do
        case "$section" in
            frontend:*) ((frontend_count++)) ;;
            backend:*) ((backend_count++)) ;;
            listen:*) ((listen_count++)) ;;
        esac
    done

    # Count servers
    for key in "${!CONFIG_ARRAYS[@]}"; do
        if [[ "$key" =~ :server:[0-9]+$ ]]; then
            ((server_count++))
        fi
    done

    echo "Configuration Statistics:"
    echo "  Total sections: ${#SECTION_LIST[@]}"
    echo "  Frontends: $frontend_count"
    echo "  Backends: $backend_count"
    echo "  Listen sections: $listen_count"
    echo "  Total servers: $server_count"
    echo "  Total directives: ${#CONFIG[@]}"
}

# Export functions
export -f parse_config_file parse_directive add_array_directive
export -f get_sections get_section_names section_exists
export -f get_directive get_array_directive
export -f get_servers get_binds get_acls get_section_directives
export -f display_section display_full_config
export -f is_config_loaded reload_if_changed get_config_stats

log_debug "Configuration parser module loaded"
