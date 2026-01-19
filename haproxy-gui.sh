#!/bin/bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HAProxy CLI GUI - Interactive Terminal Configuration Manager
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Version: 1.4.0
# Description: Production-ready HAProxy configuration manager with comprehensive features
# CRITICAL FEATURE: Mandatory backup before EVERY configuration modification
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global configuration
CONFIG_FILE="${CONFIG_FILE:-/etc/haproxy/haproxy.cfg}"
BACKUP_DIR="${BACKUP_DIR:-${SCRIPT_DIR}/backups}"
LOG_FILE="${LOG_FILE:-/var/log/haproxy-gui.log}"
DEBUG="${DEBUG:-0}"

# Load core libraries
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/backup-manager.sh"
source "${SCRIPT_DIR}/lib/config-parser.sh"
source "${SCRIPT_DIR}/lib/config-writer.sh"
source "${SCRIPT_DIR}/lib/validator.sh"
source "${SCRIPT_DIR}/lib/dialog-helpers.sh"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Initialization
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

init_application() {
    log_info "=========================================="
    log_info "HAProxy CLI GUI Starting"
    log_info "=========================================="

    # Check dependencies
    if ! check_dependencies; then
        die "Missing required dependencies. Please install them first."
    fi

    # Initialize dialog
    init_dialog

    # Check if running as root (needed for most operations)
    if ! is_root; then
        show_msgbox "Warning" "This application typically requires root privileges to modify HAProxy configuration.\n\nSome features may not work without proper permissions."
    fi

    # Create backup directory
    init_backup_dir || die "Failed to initialize backup directory"

    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        if show_yesno "Config Not Found" "HAProxy configuration file not found:\n$CONFIG_FILE\n\nWould you like to create a new one?"; then
            create_new_config
        else
            die "Cannot continue without configuration file"
        fi
    fi

    # Load configuration
    if ! parse_config_file "$CONFIG_FILE"; then
        die "Failed to parse configuration file: $CONFIG_FILE"
    fi

    show_info "Configuration loaded: $CONFIG_FILE"
}

# Create a new basic configuration
create_new_config() {
    log_info "Creating new HAProxy configuration..."

    # Create global section
    SECTION_LIST=("global" "defaults")
    CONFIG_ORDER["global"]=0
    CONFIG_ORDER["defaults"]=1

    # Add basic global settings
    CONFIG["global:daemon"]=""
    CONFIG["global:maxconn"]="4096"

    # Add basic defaults
    CONFIG["defaults:mode"]="http"
    CONFIG["defaults:timeout connect"]="5000ms"
    CONFIG["defaults:timeout client"]="50000ms"
    CONFIG["defaults:timeout server"]="50000ms"

    CONFIG_LOADED=1

    # Write configuration
    if write_config_file "$CONFIG_FILE" "Initial configuration creation"; then
        show_success "Created new configuration file"
    else
        die "Failed to create configuration file"
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Menu
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_main_menu() {
    while true; do
        local choice
        choice=$(show_menu "HAProxy CLI GUI - Main Menu" \
            "Configuration File: $CONFIG_FILE\nSelect an option:" \
            "1" "View Current Configuration" \
            "2" "Manage Frontends" \
            "3" "Manage Backends" \
            "4" "Manage Listen Sections" \
            "5" "ACL Management" \
            "6" "SSL/TLS Configuration" \
            "7" "Global Settings" \
            "8" "Defaults Settings" \
            "9" "Validation & Testing" \
            "10" "Service Control" \
            "11" "Backup & Restore" \
            "12" "Configuration File" \
            "0" "Help & Exit")

        case "$choice" in
            1) menu_view_config ;;
            2) menu_frontends ;;
            3) menu_backends ;;
            4) menu_listen ;;
            5) menu_acl ;;
            6) menu_ssl_tls ;;
            7) menu_global_settings ;;
            8) menu_defaults_settings ;;
            9) menu_validation ;;
            10) menu_service_control ;;
            11) menu_backup_restore ;;
            12) menu_config_file ;;
            0|"") menu_help_exit ;;
            *) show_msgbox "Error" "Invalid option: $choice" ;;
        esac
    done
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# View Configuration Menu
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_view_config() {
    local choice
    choice=$(show_menu "View Configuration" \
        "Select view option:" \
        "1" "View Full Configuration" \
        "2" "View by Section" \
        "3" "View Statistics" \
        "4" "View Configuration File" \
        "0" "Back to Main Menu")

    case "$choice" in
        1) view_full_config ;;
        2) view_by_section ;;
        3) view_statistics ;;
        4) view_config_file ;;
        0|"") return ;;
    esac
}

view_full_config() {
    local temp_file="/tmp/haproxy-gui-config.$$.txt"
    display_full_config > "$temp_file"
    show_textbox "Full Configuration" "$temp_file"
    rm -f "$temp_file"
}

view_by_section() {
    local sections=()
    local section

    for section in "${SECTION_LIST[@]}"; do
        sections+=("$section" "")
    done

    if [[ ${#sections[@]} -eq 0 ]]; then
        show_msgbox "Info" "No sections found in configuration"
        return
    fi

    local choice
    choice=$(show_menu "Select Section" "Choose a section to view:" "${sections[@]}")

    if [[ -n "$choice" ]]; then
        local temp_file="/tmp/haproxy-gui-section.$$.txt"
        display_section "$choice" > "$temp_file"
        show_textbox "Section: $choice" "$temp_file"
        rm -f "$temp_file"
    fi
}

view_statistics() {
    local temp_file="/tmp/haproxy-gui-stats.$$.txt"
    get_config_stats > "$temp_file"
    show_textbox "Configuration Statistics" "$temp_file"
    rm -f "$temp_file"
}

view_config_file() {
    if [[ -f "$CONFIG_FILE" ]]; then
        show_textbox "Configuration File: $CONFIG_FILE" "$CONFIG_FILE"
    else
        show_msgbox "Error" "Configuration file not found: $CONFIG_FILE"
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Frontend Management Menu (Basic Implementation)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_frontends() {
    while true; do
        local choice
        choice=$(show_menu "Frontend Management" \
            "Manage frontend sections:" \
            "1" "List Frontends" \
            "2" "Add Frontend" \
            "3" "Edit Frontend" \
            "4" "Delete Frontend" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) list_frontends ;;
            2) add_frontend ;;
            3) edit_frontend ;;
            4) delete_frontend ;;
            0|"") return ;;
        esac
    done
}

list_frontends() {
    local frontends
    frontends=$(get_section_names "frontend")

    if [[ -z "$frontends" ]]; then
        show_msgbox "Frontends" "No frontends defined"
        return
    fi

    local temp_file="/tmp/haproxy-gui-frontends.$$.txt"
    {
        echo "Defined Frontends:"
        echo "=================="
        echo ""
        for frontend in $frontends; do
            echo "Frontend: $frontend"
            display_section "frontend:$frontend"
        done
    } > "$temp_file"

    show_textbox "Frontends List" "$temp_file"
    rm -f "$temp_file"
}

add_frontend() {
    local name
    local bind
    local default_backend

    # Get frontend name
    name=$(show_inputbox "Add Frontend" "Enter frontend name (e.g., http_front):")
    if [[ -z "$name" ]]; then
        return
    fi

    if ! is_valid_section_name "$name"; then
        show_msgbox "Error" "Invalid frontend name: $name"
        return
    fi

    if section_exists "frontend:$name"; then
        show_msgbox "Error" "Frontend already exists: $name"
        return
    fi

    # Get bind address
    bind=$(show_inputbox "Add Frontend" "Enter bind address (e.g., *:80):")
    if [[ -z "$bind" ]]; then
        return
    fi

    # Get default backend
    default_backend=$(show_inputbox "Add Frontend" "Enter default backend name:")

    # Add frontend
    if add_section "frontend" "$name"; then
        set_directive "frontend:$name" "mode" "http"
        add_array_directive_value "frontend:$name" "bind" "$bind"
        if [[ -n "$default_backend" ]]; then
            set_directive "frontend:$name" "default_backend" "$default_backend"
        fi

        # Write configuration with mandatory backup
        if write_config_file "$CONFIG_FILE" "Added frontend: $name"; then
            show_msgbox "Success" "Frontend '$name' added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add frontend"
    fi
}

delete_frontend() {
    local frontends
    frontends=$(get_section_names "frontend")

    if [[ -z "$frontends" ]]; then
        show_msgbox "Info" "No frontends to delete"
        return
    fi

    # Build menu items
    local items=()
    for frontend in $frontends; do
        items+=("$frontend" "")
    done

    local choice
    choice=$(show_menu "Delete Frontend" "Select frontend to delete:" "${items[@]}")

    if [[ -n "$choice" ]]; then
        if show_yesno "Confirm Delete" "Are you sure you want to delete frontend '$choice'?"; then
            if delete_section "frontend:$choice"; then
                # Write configuration with mandatory backup
                if write_config_file "$CONFIG_FILE" "Deleted frontend: $choice"; then
                    show_msgbox "Success" "Frontend '$choice' deleted successfully!"
                else
                    show_msgbox "Error" "Failed to write configuration"
                fi
            else
                show_msgbox "Error" "Failed to delete frontend"
            fi
        fi
    fi
}

edit_frontend() {
    local frontends
    frontends=$(get_section_names "frontend")

    if [[ -z "$frontends" ]]; then
        show_msgbox "Info" "No frontends to edit"
        return
    fi

    # Select frontend to edit
    local items=()
    for frontend in $frontends; do
        items+=("$frontend" "")
    done

    local frontend_name
    frontend_name=$(show_menu "Edit Frontend" "Select frontend to edit:" "${items[@]}")

    if [[ -z "$frontend_name" ]]; then
        return
    fi

    # Frontend edit submenu
    while true; do
        local choice
        choice=$(show_menu "Edit Frontend: $frontend_name" \
            "Select what to edit:" \
            "1" "Manage Bind Addresses" \
            "2" "Change Default Backend" \
            "3" "Edit Mode" \
            "4" "View Frontend Details" \
            "0" "Back")

        case "$choice" in
            1) manage_binds "$frontend_name" ;;
            2) change_default_backend "$frontend_name" ;;
            3) edit_frontend_mode "$frontend_name" ;;
            4) view_frontend_details "$frontend_name" ;;
            0|"") return ;;
        esac
    done
}

manage_binds() {
    local frontend_name="$1"

    while true; do
        local choice
        choice=$(show_menu "Manage Bind Addresses: $frontend_name" \
            "Bind address management:" \
            "1" "List Bind Addresses" \
            "2" "Add Bind Address" \
            "3" "Delete Bind Address" \
            "0" "Back")

        case "$choice" in
            1) list_binds "$frontend_name" ;;
            2) add_bind "$frontend_name" ;;
            3) delete_bind "$frontend_name" ;;
            0|"") return ;;
        esac
    done
}

list_binds() {
    local frontend_name="$1"
    local binds
    binds=$(get_array_directive "frontend:$frontend_name" "bind")

    if [[ -z "$binds" ]]; then
        show_msgbox "Bind Addresses" "No bind addresses defined in frontend '$frontend_name'"
        return
    fi

    local temp_file="/tmp/haproxy-gui-binds.$$.txt"
    {
        echo "Bind addresses in frontend '$frontend_name':"
        echo "=============================================="
        echo ""
        local index=1
        while IFS= read -r bind; do
            if [[ -n "$bind" ]]; then
                echo "$index. $bind"
                ((index++))
            fi
        done <<< "$binds"
    } > "$temp_file"

    show_textbox "Bind Addresses" "$temp_file"
    rm -f "$temp_file"
}

add_bind() {
    local frontend_name="$1"
    local bind_address

    # Get bind address
    bind_address=$(show_inputbox "Add Bind Address" "Enter bind address (e.g., *:80 or 192.168.1.10:443):")
    if [[ -z "$bind_address" ]]; then
        return
    fi

    # Basic validation
    if ! validate_bind_address "$bind_address"; then
        show_msgbox "Error" "Invalid bind address format: $bind_address"
        return
    fi

    # Add bind to frontend
    if add_array_directive_value "frontend:$frontend_name" "bind" "$bind_address"; then
        # Write configuration with mandatory backup
        if write_config_file "$CONFIG_FILE" "Added bind address to frontend $frontend_name"; then
            show_msgbox "Success" "Bind address added successfully to frontend '$frontend_name'!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add bind address"
    fi
}

delete_bind() {
    local frontend_name="$1"
    local binds
    binds=$(get_array_directive "frontend:$frontend_name" "bind")

    if [[ -z "$binds" ]]; then
        show_msgbox "Info" "No bind addresses to delete in frontend '$frontend_name'"
        return
    fi

    # Build menu items
    local items=()
    local index=0
    while IFS= read -r bind; do
        if [[ -n "$bind" ]]; then
            items+=("$index" "$bind")
            ((index++))
        fi
    done <<< "$binds"

    local choice
    choice=$(show_menu "Delete Bind Address" "Select bind address to delete from '$frontend_name':" "${items[@]}")

    if [[ -n "$choice" ]]; then
        if show_yesno "Confirm Delete" "Are you sure you want to delete this bind address?"; then
            if delete_array_directive_value "frontend:$frontend_name" "bind" "$choice"; then
                # Write configuration with mandatory backup
                if write_config_file "$CONFIG_FILE" "Deleted bind address from frontend $frontend_name"; then
                    show_msgbox "Success" "Bind address deleted successfully from frontend '$frontend_name'!"
                else
                    show_msgbox "Error" "Failed to write configuration"
                fi
            else
                show_msgbox "Error" "Failed to delete bind address"
            fi
        fi
    fi
}

change_default_backend() {
    local frontend_name="$1"
    local current_backend
    current_backend=$(get_directive "frontend:$frontend_name" "default_backend")

    local new_backend
    new_backend=$(show_inputbox "Change Default Backend" \
        "Enter default backend name for '$frontend_name':" \
        "$current_backend")

    if [[ -n "$new_backend" ]] && [[ "$new_backend" != "$current_backend" ]]; then
        if set_directive "frontend:$frontend_name" "default_backend" "$new_backend"; then
            # Write configuration with mandatory backup
            if write_config_file "$CONFIG_FILE" "Changed default backend in frontend $frontend_name"; then
                show_msgbox "Success" "Default backend changed to '$new_backend' in frontend '$frontend_name'!"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to update default backend"
        fi
    fi
}

edit_frontend_mode() {
    local frontend_name="$1"
    local current_mode
    current_mode=$(get_directive "frontend:$frontend_name" "mode")

    local new_mode
    new_mode=$(show_radiolist "Change Mode" \
        "Select mode for '$frontend_name':" \
        "http" "HTTP mode (layer 7)" "$([ "$current_mode" = "http" ] && echo "on" || echo "off")" \
        "tcp" "TCP mode (layer 4)" "$([ "$current_mode" = "tcp" ] && echo "on" || echo "off")")

    if [[ -n "$new_mode" ]] && [[ "$new_mode" != "$current_mode" ]]; then
        if set_directive "frontend:$frontend_name" "mode" "$new_mode"; then
            # Write configuration with mandatory backup
            if write_config_file "$CONFIG_FILE" "Changed mode in frontend $frontend_name"; then
                show_msgbox "Success" "Mode changed to '$new_mode' in frontend '$frontend_name'!"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to update mode"
        fi
    fi
}

view_frontend_details() {
    local frontend_name="$1"
    local temp_file="/tmp/haproxy-gui-frontend-details.$$.txt"

    display_section "frontend:$frontend_name" > "$temp_file"
    show_textbox "Frontend Details: $frontend_name" "$temp_file"
    rm -f "$temp_file"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Backend Management Menu (Basic Implementation)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_backends() {
    while true; do
        local choice
        choice=$(show_menu "Backend Management" \
            "Manage backend sections:" \
            "1" "List Backends" \
            "2" "Add Backend" \
            "3" "Edit Backend" \
            "4" "Delete Backend" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) list_backends ;;
            2) add_backend ;;
            3) edit_backend ;;
            4) delete_backend ;;
            0|"") return ;;
        esac
    done
}

list_backends() {
    local backends
    backends=$(get_section_names "backend")

    if [[ -z "$backends" ]]; then
        show_msgbox "Backends" "No backends defined"
        return
    fi

    local temp_file="/tmp/haproxy-gui-backends.$$.txt"
    {
        echo "Defined Backends:"
        echo "=================="
        echo ""
        for backend in $backends; do
            echo "Backend: $backend"
            display_section "backend:$backend"
        done
    } > "$temp_file"

    show_textbox "Backends List" "$temp_file"
    rm -f "$temp_file"
}

add_backend() {
    local name
    local balance

    # Get backend name
    name=$(show_inputbox "Add Backend" "Enter backend name (e.g., web_servers):")
    if [[ -z "$name" ]]; then
        return
    fi

    if ! is_valid_section_name "$name"; then
        show_msgbox "Error" "Invalid backend name: $name"
        return
    fi

    if section_exists "backend:$name"; then
        show_msgbox "Error" "Backend already exists: $name"
        return
    fi

    # Get balance algorithm
    balance=$(show_radiolist "Add Backend" "Select balance algorithm:" \
        "roundrobin" "Round Robin" "on" \
        "leastconn" "Least Connections" "off" \
        "source" "Source IP Hash" "off")

    if [[ -z "$balance" ]]; then
        balance="roundrobin"
    fi

    # Add backend
    if add_section "backend" "$name"; then
        set_directive "backend:$name" "mode" "http"
        set_directive "backend:$name" "balance" "$balance"

        # Write configuration with mandatory backup
        if write_config_file "$CONFIG_FILE" "Added backend: $name"; then
            show_msgbox "Success" "Backend '$name' added successfully!\n\nYou can now add servers to this backend."
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add backend"
    fi
}

delete_backend() {
    local backends
    backends=$(get_section_names "backend")

    if [[ -z "$backends" ]]; then
        show_msgbox "Info" "No backends to delete"
        return
    fi

    # Build menu items
    local items=()
    for backend in $backends; do
        items+=("$backend" "")
    done

    local choice
    choice=$(show_menu "Delete Backend" "Select backend to delete:" "${items[@]}")

    if [[ -n "$choice" ]]; then
        if show_yesno "Confirm Delete" "Are you sure you want to delete backend '$choice'?"; then
            if delete_section "backend:$choice"; then
                # Write configuration with mandatory backup
                if write_config_file "$CONFIG_FILE" "Deleted backend: $choice"; then
                    show_msgbox "Success" "Backend '$choice' deleted successfully!"
                else
                    show_msgbox "Error" "Failed to write configuration"
                fi
            else
                show_msgbox "Error" "Failed to delete backend"
            fi
        fi
    fi
}

edit_backend() {
    local backends
    backends=$(get_section_names "backend")

    if [[ -z "$backends" ]]; then
        show_msgbox "Info" "No backends to edit"
        return
    fi

    # Select backend to edit
    local items=()
    for backend in $backends; do
        items+=("$backend" "")
    done

    local backend_name
    backend_name=$(show_menu "Edit Backend" "Select backend to edit:" "${items[@]}")

    if [[ -z "$backend_name" ]]; then
        return
    fi

    # Backend edit submenu
    while true; do
        local choice
        choice=$(show_menu "Edit Backend: $backend_name" \
            "Select what to edit:" \
            "1" "Manage Servers" \
            "2" "Change Balance Algorithm" \
            "3" "Edit Mode" \
            "4" "View Backend Details" \
            "0" "Back")

        case "$choice" in
            1) manage_servers "$backend_name" ;;
            2) change_balance_algorithm "$backend_name" ;;
            3) edit_backend_mode "$backend_name" ;;
            4) view_backend_details "$backend_name" ;;
            0|"") return ;;
        esac
    done
}

manage_servers() {
    local backend_name="$1"

    while true; do
        local choice
        choice=$(show_menu "Manage Servers: $backend_name" \
            "Server management:" \
            "1" "List Servers" \
            "2" "Add Server (Basic)" \
            "3" "Add Server (Advanced)" \
            "4" "Configure Health Checks" \
            "5" "Delete Server" \
            "0" "Back")

        case "$choice" in
            1) list_servers "$backend_name" ;;
            2) add_server "$backend_name" ;;
            3) add_server_advanced "$backend_name" ;;
            4) configure_health_checks "$backend_name" ;;
            5) delete_server "$backend_name" ;;
            0|"") return ;;
        esac
    done
}

list_servers() {
    local backend_name="$1"
    local servers
    servers=$(get_array_directive "backend:$backend_name" "server")

    if [[ -z "$servers" ]]; then
        show_msgbox "Servers" "No servers defined in backend '$backend_name'"
        return
    fi

    local temp_file="/tmp/haproxy-gui-servers.$$.txt"
    {
        echo "Servers in backend '$backend_name':"
        echo "======================================"
        echo ""
        local index=1
        while IFS= read -r server; do
            if [[ -n "$server" ]]; then
                echo "$index. $server"
                ((index++))
            fi
        done <<< "$servers"
    } > "$temp_file"

    show_textbox "Servers List" "$temp_file"
    rm -f "$temp_file"
}

add_server() {
    local backend_name="$1"
    local server_name
    local server_address
    local server_port
    local server_options

    # Get server name
    server_name=$(show_inputbox "Add Server" "Enter server name (e.g., web1):")
    if [[ -z "$server_name" ]]; then
        return
    fi

    if ! is_valid_server_name "$server_name"; then
        show_msgbox "Error" "Invalid server name: $server_name"
        return
    fi

    # Get server address
    server_address=$(show_inputbox "Add Server" "Enter server IP address:")
    if [[ -z "$server_address" ]]; then
        return
    fi

    if ! is_valid_ip "$server_address"; then
        show_msgbox "Error" "Invalid IP address: $server_address"
        return
    fi

    # Get server port
    server_port=$(show_inputbox "Add Server" "Enter server port:" "8080")
    if [[ -z "$server_port" ]]; then
        return
    fi

    if ! is_valid_port "$server_port"; then
        show_msgbox "Error" "Invalid port: $server_port"
        return
    fi

    # Get server options
    local options_choice
    options_choice=$(show_checklist "Add Server" "Select server options:" \
        "check" "Enable health checks" "on" \
        "backup" "Backup server" "off" \
        "ssl" "Use SSL to server" "off")

    # Build server line
    local server_line="$server_name $server_address:$server_port"

    # Parse selected options
    if [[ "$options_choice" =~ "check" ]]; then
        server_line="$server_line check"
    fi
    if [[ "$options_choice" =~ "backup" ]]; then
        server_line="$server_line backup"
    fi
    if [[ "$options_choice" =~ "ssl" ]]; then
        server_line="$server_line ssl verify none"
    fi

    # Add server to backend
    if add_array_directive_value "backend:$backend_name" "server" "$server_line"; then
        # Write configuration with mandatory backup
        if write_config_file "$CONFIG_FILE" "Added server $server_name to backend $backend_name"; then
            show_msgbox "Success" "Server '$server_name' added successfully to backend '$backend_name'!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add server"
    fi
}

add_server_advanced() {
    local backend_name="$1"
    local server_name
    local server_address
    local server_port
    local weight
    local maxconn
    local inter
    local rise
    local fall

    # Get server name
    server_name=$(show_inputbox "Add Server (Advanced)" "Enter server name (e.g., web1):")
    if [[ -z "$server_name" ]]; then
        return
    fi

    if ! is_valid_server_name "$server_name"; then
        show_msgbox "Error" "Invalid server name: $server_name"
        return
    fi

    # Get server address
    server_address=$(show_inputbox "Add Server (Advanced)" "Enter server IP address or hostname:")
    if [[ -z "$server_address" ]]; then
        return
    fi

    # Get server port
    server_port=$(show_inputbox "Add Server (Advanced)" "Enter server port:" "8080")
    if [[ -z "$server_port" ]]; then
        return
    fi

    if ! is_valid_port "$server_port"; then
        show_msgbox "Error" "Invalid port: $server_port"
        return
    fi

    # Get weight
    weight=$(show_inputbox "Server Weight" "Enter server weight (1-256, higher = more traffic):" "100")
    if [[ -n "$weight" ]] && ! [[ "$weight" =~ ^[0-9]+$ ]]; then
        show_msgbox "Error" "Invalid weight: $weight"
        return
    fi

    # Get maxconn
    maxconn=$(show_inputbox "Server Max Connections" "Enter max connections (leave empty for unlimited):")
    if [[ -n "$maxconn" ]] && ! [[ "$maxconn" =~ ^[0-9]+$ ]]; then
        show_msgbox "Error" "Invalid maxconn: $maxconn"
        return
    fi

    # Get health check interval
    inter=$(show_inputbox "Health Check Interval" "Enter check interval in milliseconds:" "2000")
    if [[ -n "$inter" ]] && ! [[ "$inter" =~ ^[0-9]+$ ]]; then
        show_msgbox "Error" "Invalid interval: $inter"
        return
    fi

    # Get rise count
    rise=$(show_inputbox "Health Check Rise" "Number of successful checks to mark UP:" "2")
    if [[ -n "$rise" ]] && ! [[ "$rise" =~ ^[0-9]+$ ]]; then
        show_msgbox "Error" "Invalid rise count: $rise"
        return
    fi

    # Get fall count
    fall=$(show_inputbox "Health Check Fall" "Number of failed checks to mark DOWN:" "3")
    if [[ -n "$fall" ]] && ! [[ "$fall" =~ ^[0-9]+$ ]]; then
        show_msgbox "Error" "Invalid fall count: $fall"
        return
    fi

    # Get server options
    local options_choice
    options_choice=$(show_checklist "Add Server Options" "Select server options:" \
        "check" "Enable health checks" "on" \
        "backup" "Backup server" "off" \
        "ssl" "Use SSL to server" "off" \
        "send-proxy" "Send PROXY protocol header" "off")

    # Build server line
    local server_line="$server_name $server_address:$server_port"

    # Add weight
    if [[ -n "$weight" ]]; then
        server_line="$server_line weight $weight"
    fi

    # Add maxconn
    if [[ -n "$maxconn" ]]; then
        server_line="$server_line maxconn $maxconn"
    fi

    # Add health check parameters
    if [[ "$options_choice" =~ "check" ]]; then
        server_line="$server_line check"
        if [[ -n "$inter" ]]; then
            server_line="$server_line inter ${inter}ms"
        fi
        if [[ -n "$rise" ]]; then
            server_line="$server_line rise $rise"
        fi
        if [[ -n "$fall" ]]; then
            server_line="$server_line fall $fall"
        fi
    fi

    # Add other options
    if [[ "$options_choice" =~ "backup" ]]; then
        server_line="$server_line backup"
    fi
    if [[ "$options_choice" =~ "ssl" ]]; then
        server_line="$server_line ssl verify none"
    fi
    if [[ "$options_choice" =~ "send-proxy" ]]; then
        server_line="$server_line send-proxy"
    fi

    # Add server to backend
    if add_array_directive_value "backend:$backend_name" "server" "$server_line"; then
        if write_config_file "$CONFIG_FILE" "Added advanced server $server_name to backend $backend_name"; then
            show_msgbox "Success" "Server '$server_name' added successfully with advanced options!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add server"
    fi
}

configure_health_checks() {
    local backend_name="$1"

    while true; do
        local choice
        choice=$(show_menu "Health Check Configuration: $backend_name" \
            "Configure health checks for backend:" \
            "1" "HTTP Health Check" \
            "2" "TCP Health Check" \
            "3" "MySQL Health Check" \
            "4" "PostgreSQL Health Check" \
            "5" "Redis Health Check" \
            "6" "SMTP Health Check" \
            "7" "SSL Health Check" \
            "8" "View Current Health Check" \
            "0" "Back")

        case "$choice" in
            1) configure_http_check "$backend_name" ;;
            2) configure_tcp_check "$backend_name" ;;
            3) configure_mysql_check "$backend_name" ;;
            4) configure_pgsql_check "$backend_name" ;;
            5) configure_redis_check "$backend_name" ;;
            6) configure_smtp_check "$backend_name" ;;
            7) configure_ssl_check "$backend_name" ;;
            8) view_health_check_config "$backend_name" ;;
            0|"") return ;;
        esac
    done
}

configure_http_check() {
    local backend_name="$1"
    local uri
    local method
    local expect

    uri=$(show_inputbox "HTTP Health Check" "Enter URI to check (e.g., /health):" "/")
    if [[ -z "$uri" ]]; then
        return
    fi

    method=$(show_radiolist "HTTP Method" "Select HTTP method:" \
        "GET" "GET request" "on" \
        "HEAD" "HEAD request" "off" \
        "POST" "POST request" "off")

    if [[ -z "$method" ]]; then
        method="GET"
    fi

    expect=$(show_inputbox "Expected Response" "Enter expected HTTP status code (leave empty for any 2xx/3xx):" "200")

    # Set option httpchk
    if set_directive "backend:$backend_name" "option httpchk" "$method $uri"; then
        # Add expect if specified
        if [[ -n "$expect" ]]; then
            set_directive "backend:$backend_name" "http-check expect" "status $expect"
        fi

        if write_config_file "$CONFIG_FILE" "Configured HTTP health check for backend $backend_name"; then
            show_msgbox "Success" "HTTP health check configured!\n\nMethod: $method\nURI: $uri\nExpected: ${expect:-any 2xx/3xx}"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to configure HTTP health check"
    fi
}

configure_tcp_check() {
    local backend_name="$1"
    local send_data
    local expect_data

    send_data=$(show_inputbox "TCP Health Check" "Enter data to send (leave empty for simple connect check):")

    if [[ -n "$send_data" ]]; then
        expect_data=$(show_inputbox "TCP Health Check" "Enter expected response data:")

        if [[ -n "$expect_data" ]]; then
            if set_directive "backend:$backend_name" "option tcp-check" "" && \
               set_directive "backend:$backend_name" "tcp-check send" "$send_data" && \
               set_directive "backend:$backend_name" "tcp-check expect" "string $expect_data"; then

                if write_config_file "$CONFIG_FILE" "Configured TCP health check for backend $backend_name"; then
                    show_msgbox "Success" "TCP health check configured with send/expect!"
                else
                    show_msgbox "Error" "Failed to write configuration"
                fi
            else
                show_msgbox "Error" "Failed to configure TCP health check"
            fi
        fi
    else
        if set_directive "backend:$backend_name" "option tcp-check" ""; then
            if write_config_file "$CONFIG_FILE" "Configured simple TCP health check for backend $backend_name"; then
                show_msgbox "Success" "Simple TCP health check configured!"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to configure TCP health check"
        fi
    fi
}

configure_mysql_check() {
    local backend_name="$1"
    local username

    username=$(show_inputbox "MySQL Health Check" "Enter MySQL username for health check:" "haproxy_check")
    if [[ -z "$username" ]]; then
        return
    fi

    if set_directive "backend:$backend_name" "option mysql-check" "user $username"; then
        if write_config_file "$CONFIG_FILE" "Configured MySQL health check for backend $backend_name"; then
            show_msgbox "Success" "MySQL health check configured!\n\nUsername: $username\n\nNote: Create user with:\nCREATE USER '$username'@'%';\nGRANT USAGE ON *.* TO '$username'@'%';"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to configure MySQL health check"
    fi
}

configure_pgsql_check() {
    local backend_name="$1"
    local username

    username=$(show_inputbox "PostgreSQL Health Check" "Enter PostgreSQL username for health check:" "haproxy_check")
    if [[ -z "$username" ]]; then
        return
    fi

    if set_directive "backend:$backend_name" "option pgsql-check" "user $username"; then
        if write_config_file "$CONFIG_FILE" "Configured PostgreSQL health check for backend $backend_name"; then
            show_msgbox "Success" "PostgreSQL health check configured!\n\nUsername: $username"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to configure PostgreSQL health check"
    fi
}

configure_redis_check() {
    local backend_name="$1"

    if set_directive "backend:$backend_name" "option redis-check" ""; then
        if write_config_file "$CONFIG_FILE" "Configured Redis health check for backend $backend_name"; then
            show_msgbox "Success" "Redis health check configured!\n\nSends PING, expects +PONG"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to configure Redis health check"
    fi
}

configure_smtp_check() {
    local backend_name="$1"
    local hello_domain

    hello_domain=$(show_inputbox "SMTP Health Check" "Enter EHLO/HELO domain name:" "localhost")
    if [[ -z "$hello_domain" ]]; then
        hello_domain="localhost"
    fi

    if set_directive "backend:$backend_name" "option smtpchk" "EHLO $hello_domain"; then
        if write_config_file "$CONFIG_FILE" "Configured SMTP health check for backend $backend_name"; then
            show_msgbox "Success" "SMTP health check configured!\n\nHELO domain: $hello_domain"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to configure SMTP health check"
    fi
}

configure_ssl_check() {
    local backend_name="$1"

    if set_directive "backend:$backend_name" "option ssl-hello-chk" ""; then
        if write_config_file "$CONFIG_FILE" "Configured SSL health check for backend $backend_name"; then
            show_msgbox "Success" "SSL hello health check configured!\n\nSends SSLv3 CLIENT HELLO"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to configure SSL health check"
    fi
}

view_health_check_config() {
    local backend_name="$1"
    local temp_file="/tmp/haproxy-gui-health-check.$$.txt"

    {
        echo "Health Check Configuration for: $backend_name"
        echo "=============================================="
        echo ""

        local httpchk
        httpchk=$(get_directive "backend:$backend_name" "option httpchk")
        if [[ -n "$httpchk" ]]; then
            echo "Type: HTTP Health Check"
            echo "Config: option httpchk $httpchk"

            local http_expect
            http_expect=$(get_directive "backend:$backend_name" "http-check expect")
            if [[ -n "$http_expect" ]]; then
                echo "Expect: $http_expect"
            fi
        fi

        local tcp_check
        tcp_check=$(get_directive "backend:$backend_name" "option tcp-check")
        if [[ -n "$tcp_check" ]]; then
            echo "Type: TCP Health Check"

            local tcp_send
            tcp_send=$(get_directive "backend:$backend_name" "tcp-check send")
            if [[ -n "$tcp_send" ]]; then
                echo "Send: $tcp_send"
            fi

            local tcp_expect
            tcp_expect=$(get_directive "backend:$backend_name" "tcp-check expect")
            if [[ -n "$tcp_expect" ]]; then
                echo "Expect: $tcp_expect"
            fi
        fi

        local mysql_check
        mysql_check=$(get_directive "backend:$backend_name" "option mysql-check")
        if [[ -n "$mysql_check" ]]; then
            echo "Type: MySQL Health Check"
            echo "Config: $mysql_check"
        fi

        local pgsql_check
        pgsql_check=$(get_directive "backend:$backend_name" "option pgsql-check")
        if [[ -n "$pgsql_check" ]]; then
            echo "Type: PostgreSQL Health Check"
            echo "Config: $pgsql_check"
        fi

        local redis_check
        redis_check=$(get_directive "backend:$backend_name" "option redis-check")
        if [[ -n "$redis_check" ]]; then
            echo "Type: Redis Health Check"
        fi

        local smtp_check
        smtp_check=$(get_directive "backend:$backend_name" "option smtpchk")
        if [[ -n "$smtp_check" ]]; then
            echo "Type: SMTP Health Check"
            echo "Config: $smtp_check"
        fi

        local ssl_check
        ssl_check=$(get_directive "backend:$backend_name" "option ssl-hello-chk")
        if [[ -n "$ssl_check" ]]; then
            echo "Type: SSL Hello Health Check"
        fi

        if [[ -z "$httpchk" ]] && [[ -z "$tcp_check" ]] && [[ -z "$mysql_check" ]] && \
           [[ -z "$pgsql_check" ]] && [[ -z "$redis_check" ]] && [[ -z "$smtp_check" ]] && \
           [[ -z "$ssl_check" ]]; then
            echo "No specific health check configured"
            echo "Default: Simple TCP connect check on server lines with 'check' option"
        fi
    } > "$temp_file"

    show_textbox "Health Check Configuration" "$temp_file"
    rm -f "$temp_file"
}

delete_server() {
    local backend_name="$1"
    local servers
    servers=$(get_array_directive "backend:$backend_name" "server")

    if [[ -z "$servers" ]]; then
        show_msgbox "Info" "No servers to delete in backend '$backend_name'"
        return
    fi

    # Build menu items
    local items=()
    local index=0
    while IFS= read -r server; do
        if [[ -n "$server" ]]; then
            items+=("$index" "$server")
            ((index++))
        fi
    done <<< "$servers"

    local choice
    choice=$(show_menu "Delete Server" "Select server to delete from '$backend_name':" "${items[@]}")

    if [[ -n "$choice" ]]; then
        if show_yesno "Confirm Delete" "Are you sure you want to delete this server?"; then
            if delete_array_directive_value "backend:$backend_name" "server" "$choice"; then
                # Write configuration with mandatory backup
                if write_config_file "$CONFIG_FILE" "Deleted server from backend $backend_name"; then
                    show_msgbox "Success" "Server deleted successfully from backend '$backend_name'!"
                else
                    show_msgbox "Error" "Failed to write configuration"
                fi
            else
                show_msgbox "Error" "Failed to delete server"
            fi
        fi
    fi
}

change_balance_algorithm() {
    local backend_name="$1"
    local current_balance
    current_balance=$(get_directive "backend:$backend_name" "balance")

    local new_balance
    new_balance=$(show_radiolist "Change Balance Algorithm" \
        "Select balance algorithm for '$backend_name':" \
        "roundrobin" "Round Robin" "$([ "$current_balance" = "roundrobin" ] && echo "on" || echo "off")" \
        "leastconn" "Least Connections" "$([ "$current_balance" = "leastconn" ] && echo "on" || echo "off")" \
        "source" "Source IP Hash" "$([ "$current_balance" = "source" ] && echo "on" || echo "off")" \
        "uri" "URI Hash" "$([ "$current_balance" = "uri" ] && echo "on" || echo "off")")

    if [[ -n "$new_balance" ]] && [[ "$new_balance" != "$current_balance" ]]; then
        if set_directive "backend:$backend_name" "balance" "$new_balance"; then
            # Write configuration with mandatory backup
            if write_config_file "$CONFIG_FILE" "Changed balance algorithm in backend $backend_name"; then
                show_msgbox "Success" "Balance algorithm changed to '$new_balance' in backend '$backend_name'!"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to update balance algorithm"
        fi
    fi
}

edit_backend_mode() {
    local backend_name="$1"
    local current_mode
    current_mode=$(get_directive "backend:$backend_name" "mode")

    local new_mode
    new_mode=$(show_radiolist "Change Mode" \
        "Select mode for '$backend_name':" \
        "http" "HTTP mode (layer 7)" "$([ "$current_mode" = "http" ] && echo "on" || echo "off")" \
        "tcp" "TCP mode (layer 4)" "$([ "$current_mode" = "tcp" ] && echo "on" || echo "off")")

    if [[ -n "$new_mode" ]] && [[ "$new_mode" != "$current_mode" ]]; then
        if set_directive "backend:$backend_name" "mode" "$new_mode"; then
            # Write configuration with mandatory backup
            if write_config_file "$CONFIG_FILE" "Changed mode in backend $backend_name"; then
                show_msgbox "Success" "Mode changed to '$new_mode' in backend '$backend_name'!"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to update mode"
        fi
    fi
}

view_backend_details() {
    local backend_name="$1"
    local temp_file="/tmp/haproxy-gui-backend-details.$$.txt"

    display_section "backend:$backend_name" > "$temp_file"
    show_textbox "Backend Details: $backend_name" "$temp_file"
    rm -f "$temp_file"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Listen Sections Management (Combined Frontend/Backend)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_listen() {
    while true; do
        local choice
        choice=$(show_menu "Listen Sections Management" \
            "Manage listen sections (combined frontend/backend):" \
            "1" "List Listen Sections" \
            "2" "Add Listen Section" \
            "3" "Edit Listen Section" \
            "4" "Delete Listen Section" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) list_listen ;;
            2) add_listen ;;
            3) edit_listen ;;
            4) delete_listen ;;
            0|"") return ;;
        esac
    done
}

list_listen() {
    local listen_sections
    listen_sections=$(get_section_names "listen")

    if [[ -z "$listen_sections" ]]; then
        show_msgbox "Listen Sections" "No listen sections defined"
        return
    fi

    local temp_file="/tmp/haproxy-gui-listen.$$.txt"
    {
        echo "Defined Listen Sections:"
        echo "========================"
        echo ""
        for listen in $listen_sections; do
            echo "Listen: $listen"
            display_section "listen:$listen"
            echo ""
        done
    } > "$temp_file"

    show_textbox "Listen Sections List" "$temp_file"
    rm -f "$temp_file"
}

add_listen() {
    local name
    local bind
    local mode

    # Get listen section name
    name=$(show_inputbox "Add Listen Section" "Enter listen section name (e.g., stats or web_lb):")
    if [[ -z "$name" ]]; then
        return
    fi

    if ! is_valid_section_name "$name"; then
        show_msgbox "Error" "Invalid listen section name: $name"
        return
    fi

    if section_exists "listen:$name"; then
        show_msgbox "Error" "Listen section already exists: $name"
        return
    fi

    # Get bind address
    bind=$(show_inputbox "Add Listen Section" "Enter bind address (e.g., *:8080 or *:1936 for stats):")
    if [[ -z "$bind" ]]; then
        return
    fi

    # Get mode
    mode=$(show_radiolist "Add Listen Section" "Select mode:" \
        "http" "HTTP mode (layer 7)" "on" \
        "tcp" "TCP mode (layer 4)" "off")

    if [[ -z "$mode" ]]; then
        mode="http"
    fi

    # Add listen section
    if add_section "listen" "$name"; then
        set_directive "listen:$name" "mode" "$mode"
        add_array_directive_value "listen:$name" "bind" "$bind"

        # Write configuration with mandatory backup
        if write_config_file "$CONFIG_FILE" "Added listen section: $name"; then
            show_msgbox "Success" "Listen section '$name' added successfully!\n\nYou can now add servers or configure stats interface."
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add listen section"
    fi
}

delete_listen() {
    local listen_sections
    listen_sections=$(get_section_names "listen")

    if [[ -z "$listen_sections" ]]; then
        show_msgbox "Info" "No listen sections to delete"
        return
    fi

    # Build menu items
    local items=()
    for listen in $listen_sections; do
        items+=("$listen" "")
    done

    local choice
    choice=$(show_menu "Delete Listen Section" "Select listen section to delete:" "${items[@]}")

    if [[ -n "$choice" ]]; then
        if show_yesno "Confirm Delete" "Are you sure you want to delete listen section '$choice'?"; then
            if delete_section "listen:$choice"; then
                # Write configuration with mandatory backup
                if write_config_file "$CONFIG_FILE" "Deleted listen section: $choice"; then
                    show_msgbox "Success" "Listen section '$choice' deleted successfully!"
                else
                    show_msgbox "Error" "Failed to write configuration"
                fi
            else
                show_msgbox "Error" "Failed to delete listen section"
            fi
        fi
    fi
}

edit_listen() {
    local listen_sections
    listen_sections=$(get_section_names "listen")

    if [[ -z "$listen_sections" ]]; then
        show_msgbox "Info" "No listen sections to edit"
        return
    fi

    # Select listen section to edit
    local items=()
    for listen in $listen_sections; do
        items+=("$listen" "")
    done

    local listen_name
    listen_name=$(show_menu "Edit Listen Section" "Select listen section to edit:" "${items[@]}")

    if [[ -z "$listen_name" ]]; then
        return
    fi

    # Listen edit submenu
    while true; do
        local choice
        choice=$(show_menu "Edit Listen: $listen_name" \
            "Select what to edit:" \
            "1" "Manage Bind Addresses" \
            "2" "Manage Servers" \
            "3" "Configure Stats Interface" \
            "4" "Change Balance Algorithm" \
            "5" "Edit Mode" \
            "6" "View Listen Details" \
            "0" "Back")

        case "$choice" in
            1) manage_listen_binds "$listen_name" ;;
            2) manage_listen_servers "$listen_name" ;;
            3) configure_stats_interface "$listen_name" ;;
            4) change_listen_balance "$listen_name" ;;
            5) edit_listen_mode "$listen_name" ;;
            6) view_listen_details "$listen_name" ;;
            0|"") return ;;
        esac
    done
}

manage_listen_binds() {
    local listen_name="$1"

    while true; do
        local choice
        choice=$(show_menu "Manage Bind Addresses: $listen_name" \
            "Bind address management:" \
            "1" "List Bind Addresses" \
            "2" "Add Bind Address" \
            "3" "Delete Bind Address" \
            "0" "Back")

        case "$choice" in
            1) list_listen_binds "$listen_name" ;;
            2) add_listen_bind "$listen_name" ;;
            3) delete_listen_bind "$listen_name" ;;
            0|"") return ;;
        esac
    done
}

list_listen_binds() {
    local listen_name="$1"
    local binds
    binds=$(get_array_directive "listen:$listen_name" "bind")

    if [[ -z "$binds" ]]; then
        show_msgbox "Bind Addresses" "No bind addresses defined in listen '$listen_name'"
        return
    fi

    local temp_file="/tmp/haproxy-gui-listen-binds.$$.txt"
    {
        echo "Bind addresses in listen '$listen_name':"
        echo "=========================================="
        echo ""
        local index=1
        while IFS= read -r bind; do
            if [[ -n "$bind" ]]; then
                echo "$index. $bind"
                ((index++))
            fi
        done <<< "$binds"
    } > "$temp_file"

    show_textbox "Bind Addresses" "$temp_file"
    rm -f "$temp_file"
}

add_listen_bind() {
    local listen_name="$1"
    local bind_address

    bind_address=$(show_inputbox "Add Bind Address" "Enter bind address (e.g., *:80 or 192.168.1.10:443):")
    if [[ -z "$bind_address" ]]; then
        return
    fi

    if ! validate_bind_address "$bind_address"; then
        show_msgbox "Error" "Invalid bind address format: $bind_address"
        return
    fi

    if add_array_directive_value "listen:$listen_name" "bind" "$bind_address"; then
        if write_config_file "$CONFIG_FILE" "Added bind address to listen $listen_name"; then
            show_msgbox "Success" "Bind address added successfully to listen '$listen_name'!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add bind address"
    fi
}

delete_listen_bind() {
    local listen_name="$1"
    local binds
    binds=$(get_array_directive "listen:$listen_name" "bind")

    if [[ -z "$binds" ]]; then
        show_msgbox "Info" "No bind addresses to delete in listen '$listen_name'"
        return
    fi

    # Build menu items
    local items=()
    local index=0
    while IFS= read -r bind; do
        if [[ -n "$bind" ]]; then
            items+=("$index" "$bind")
            ((index++))
        fi
    done <<< "$binds"

    local choice
    choice=$(show_menu "Delete Bind Address" "Select bind address to delete from '$listen_name':" "${items[@]}")

    if [[ -n "$choice" ]]; then
        if show_yesno "Confirm Delete" "Are you sure you want to delete this bind address?"; then
            if delete_array_directive_value "listen:$listen_name" "bind" "$choice"; then
                if write_config_file "$CONFIG_FILE" "Deleted bind address from listen $listen_name"; then
                    show_msgbox "Success" "Bind address deleted successfully!"
                else
                    show_msgbox "Error" "Failed to write configuration"
                fi
            else
                show_msgbox "Error" "Failed to delete bind address"
            fi
        fi
    fi
}

manage_listen_servers() {
    local listen_name="$1"

    while true; do
        local choice
        choice=$(show_menu "Manage Servers: $listen_name" \
            "Server management:" \
            "1" "List Servers" \
            "2" "Add Server" \
            "3" "Delete Server" \
            "0" "Back")

        case "$choice" in
            1) list_listen_servers "$listen_name" ;;
            2) add_listen_server "$listen_name" ;;
            3) delete_listen_server "$listen_name" ;;
            0|"") return ;;
        esac
    done
}

list_listen_servers() {
    local listen_name="$1"
    local servers
    servers=$(get_array_directive "listen:$listen_name" "server")

    if [[ -z "$servers" ]]; then
        show_msgbox "Servers" "No servers defined in listen '$listen_name'"
        return
    fi

    local temp_file="/tmp/haproxy-gui-listen-servers.$$.txt"
    {
        echo "Servers in listen '$listen_name':"
        echo "===================================="
        echo ""
        local index=1
        while IFS= read -r server; do
            if [[ -n "$server" ]]; then
                echo "$index. $server"
                ((index++))
            fi
        done <<< "$servers"
    } > "$temp_file"

    show_textbox "Servers List" "$temp_file"
    rm -f "$temp_file"
}

add_listen_server() {
    local listen_name="$1"
    local server_name
    local server_address
    local server_port

    # Get server name
    server_name=$(show_inputbox "Add Server" "Enter server name (e.g., web1):")
    if [[ -z "$server_name" ]]; then
        return
    fi

    if ! is_valid_server_name "$server_name"; then
        show_msgbox "Error" "Invalid server name: $server_name"
        return
    fi

    # Get server address
    server_address=$(show_inputbox "Add Server" "Enter server IP address:")
    if [[ -z "$server_address" ]]; then
        return
    fi

    if ! is_valid_ip "$server_address"; then
        show_msgbox "Error" "Invalid IP address: $server_address"
        return
    fi

    # Get server port
    server_port=$(show_inputbox "Add Server" "Enter server port:" "8080")
    if [[ -z "$server_port" ]]; then
        return
    fi

    if ! is_valid_port "$server_port"; then
        show_msgbox "Error" "Invalid port: $server_port"
        return
    fi

    # Get server options
    local options_choice
    options_choice=$(show_checklist "Add Server" "Select server options:" \
        "check" "Enable health checks" "on" \
        "backup" "Backup server" "off" \
        "ssl" "Use SSL to server" "off")

    # Build server line
    local server_line="$server_name $server_address:$server_port"

    if [[ "$options_choice" =~ "check" ]]; then
        server_line="$server_line check"
    fi
    if [[ "$options_choice" =~ "backup" ]]; then
        server_line="$server_line backup"
    fi
    if [[ "$options_choice" =~ "ssl" ]]; then
        server_line="$server_line ssl verify none"
    fi

    # Add server
    if add_array_directive_value "listen:$listen_name" "server" "$server_line"; then
        if write_config_file "$CONFIG_FILE" "Added server $server_name to listen $listen_name"; then
            show_msgbox "Success" "Server '$server_name' added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add server"
    fi
}

delete_listen_server() {
    local listen_name="$1"
    local servers
    servers=$(get_array_directive "listen:$listen_name" "server")

    if [[ -z "$servers" ]]; then
        show_msgbox "Info" "No servers to delete in listen '$listen_name'"
        return
    fi

    # Build menu items
    local items=()
    local index=0
    while IFS= read -r server; do
        if [[ -n "$server" ]]; then
            items+=("$index" "$server")
            ((index++))
        fi
    done <<< "$servers"

    local choice
    choice=$(show_menu "Delete Server" "Select server to delete from '$listen_name':" "${items[@]}")

    if [[ -n "$choice" ]]; then
        if show_yesno "Confirm Delete" "Are you sure you want to delete this server?"; then
            if delete_array_directive_value "listen:$listen_name" "server" "$choice"; then
                if write_config_file "$CONFIG_FILE" "Deleted server from listen $listen_name"; then
                    show_msgbox "Success" "Server deleted successfully!"
                else
                    show_msgbox "Error" "Failed to write configuration"
                fi
            else
                show_msgbox "Error" "Failed to delete server"
            fi
        fi
    fi
}

configure_stats_interface() {
    local listen_name="$1"

    while true; do
        local choice
        choice=$(show_menu "Stats Interface: $listen_name" \
            "Configure HAProxy stats interface:" \
            "1" "Enable Stats" \
            "2" "Set Stats URI" \
            "3" "Set Stats Auth" \
            "4" "Set Stats Refresh" \
            "5" "Enable Admin Level" \
            "6" "Disable Stats" \
            "0" "Back")

        case "$choice" in
            1) enable_stats "$listen_name" ;;
            2) set_stats_uri "$listen_name" ;;
            3) set_stats_auth "$listen_name" ;;
            4) set_stats_refresh "$listen_name" ;;
            5) enable_stats_admin "$listen_name" ;;
            6) disable_stats "$listen_name" ;;
            0|"") return ;;
        esac
    done
}

enable_stats() {
    local listen_name="$1"

    if set_directive "listen:$listen_name" "stats enable" ""; then
        if write_config_file "$CONFIG_FILE" "Enabled stats in listen $listen_name"; then
            show_msgbox "Success" "Stats interface enabled!\n\nUse 'Set Stats URI' to configure the access path."
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to enable stats"
    fi
}

set_stats_uri() {
    local listen_name="$1"
    local uri

    uri=$(show_inputbox "Set Stats URI" "Enter stats URI path (e.g., /stats or /haproxy?stats):" "/stats")
    if [[ -z "$uri" ]]; then
        return
    fi

    if set_directive "listen:$listen_name" "stats uri" "$uri"; then
        if write_config_file "$CONFIG_FILE" "Set stats URI in listen $listen_name"; then
            show_msgbox "Success" "Stats URI set to: $uri"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to set stats URI"
    fi
}

set_stats_auth() {
    local listen_name="$1"
    local username
    local password

    username=$(show_inputbox "Stats Authentication" "Enter username for stats access:")
    if [[ -z "$username" ]]; then
        return
    fi

    password=$(show_passwordbox "Stats Authentication" "Enter password for stats access:")
    if [[ -z "$password" ]]; then
        return
    fi

    if set_directive "listen:$listen_name" "stats auth" "$username:$password"; then
        if write_config_file "$CONFIG_FILE" "Set stats auth in listen $listen_name"; then
            show_msgbox "Success" "Stats authentication configured!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to set stats authentication"
    fi
}

set_stats_refresh() {
    local listen_name="$1"
    local refresh

    refresh=$(show_inputbox "Stats Refresh" "Enter auto-refresh interval in seconds (0 to disable):" "30")
    if [[ -z "$refresh" ]]; then
        return
    fi

    if ! [[ "$refresh" =~ ^[0-9]+$ ]]; then
        show_msgbox "Error" "Invalid refresh interval: $refresh"
        return
    fi

    if set_directive "listen:$listen_name" "stats refresh" "${refresh}s"; then
        if write_config_file "$CONFIG_FILE" "Set stats refresh in listen $listen_name"; then
            show_msgbox "Success" "Stats refresh interval set to ${refresh}s"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to set stats refresh"
    fi
}

enable_stats_admin() {
    local listen_name="$1"

    if show_yesno "Warning" "Admin level allows modifying server states via web interface.\n\nThis can be dangerous in production.\n\nContinue?"; then
        if set_directive "listen:$listen_name" "stats admin" "if TRUE"; then
            if write_config_file "$CONFIG_FILE" "Enabled stats admin in listen $listen_name"; then
                show_msgbox "Success" "Stats admin level enabled!"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to enable stats admin"
        fi
    fi
}

disable_stats() {
    local listen_name="$1"

    if show_yesno "Confirm" "This will disable the stats interface.\n\nContinue?"; then
        if delete_directive "listen:$listen_name" "stats enable"; then
            delete_directive "listen:$listen_name" "stats uri"
            delete_directive "listen:$listen_name" "stats auth"
            delete_directive "listen:$listen_name" "stats refresh"
            delete_directive "listen:$listen_name" "stats admin"

            if write_config_file "$CONFIG_FILE" "Disabled stats in listen $listen_name"; then
                show_msgbox "Success" "Stats interface disabled"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to disable stats"
        fi
    fi
}

change_listen_balance() {
    local listen_name="$1"
    local current_balance
    current_balance=$(get_directive "listen:$listen_name" "balance")

    local new_balance
    new_balance=$(show_radiolist "Change Balance Algorithm" \
        "Select balance algorithm for '$listen_name':" \
        "roundrobin" "Round Robin" "$([ "$current_balance" = "roundrobin" ] && echo "on" || echo "off")" \
        "leastconn" "Least Connections" "$([ "$current_balance" = "leastconn" ] && echo "on" || echo "off")" \
        "source" "Source IP Hash" "$([ "$current_balance" = "source" ] && echo "on" || echo "off")")

    if [[ -n "$new_balance" ]] && [[ "$new_balance" != "$current_balance" ]]; then
        if set_directive "listen:$listen_name" "balance" "$new_balance"; then
            if write_config_file "$CONFIG_FILE" "Changed balance algorithm in listen $listen_name"; then
                show_msgbox "Success" "Balance algorithm changed to '$new_balance'!"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to update balance algorithm"
        fi
    fi
}

edit_listen_mode() {
    local listen_name="$1"
    local current_mode
    current_mode=$(get_directive "listen:$listen_name" "mode")

    local new_mode
    new_mode=$(show_radiolist "Change Mode" \
        "Select mode for '$listen_name':" \
        "http" "HTTP mode (layer 7)" "$([ "$current_mode" = "http" ] && echo "on" || echo "off")" \
        "tcp" "TCP mode (layer 4)" "$([ "$current_mode" = "tcp" ] && echo "on" || echo "off")")

    if [[ -n "$new_mode" ]] && [[ "$new_mode" != "$current_mode" ]]; then
        if set_directive "listen:$listen_name" "mode" "$new_mode"; then
            if write_config_file "$CONFIG_FILE" "Changed mode in listen $listen_name"; then
                show_msgbox "Success" "Mode changed to '$new_mode'!"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to update mode"
        fi
    fi
}

view_listen_details() {
    local listen_name="$1"
    local temp_file="/tmp/haproxy-gui-listen-details.$$.txt"

    display_section "listen:$listen_name" > "$temp_file"
    show_textbox "Listen Details: $listen_name" "$temp_file"
    rm -f "$temp_file"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ACL Management System
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_acl() {
    while true; do
        local choice
        choice=$(show_menu "ACL Management" \
            "Manage Access Control Lists:" \
            "1" "Manage Frontend ACLs" \
            "2" "Manage Listen ACLs" \
            "3" "ACL Templates Library" \
            "4" "Test ACL Expression" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) select_frontend_for_acl ;;
            2) select_listen_for_acl ;;
            3) acl_templates_library ;;
            4) test_acl_expression ;;
            0|"") return ;;
        esac
    done
}

select_frontend_for_acl() {
    local frontends
    frontends=$(get_section_names "frontend")

    if [[ -z "$frontends" ]]; then
        show_msgbox "Info" "No frontends defined. Create a frontend first."
        return
    fi

    # Build menu items
    local items=()
    for frontend in $frontends; do
        items+=("$frontend" "")
    done

    local choice
    choice=$(show_menu "Select Frontend" "Select frontend to manage ACLs:" "${items[@]}")

    if [[ -n "$choice" ]]; then
        manage_section_acls "frontend:$choice" "$choice"
    fi
}

select_listen_for_acl() {
    local listen_sections
    listen_sections=$(get_section_names "listen")

    if [[ -z "$listen_sections" ]]; then
        show_msgbox "Info" "No listen sections defined. Create a listen section first."
        return
    fi

    # Build menu items
    local items=()
    for listen in $listen_sections; do
        items+=("$listen" "")
    done

    local choice
    choice=$(show_menu "Select Listen Section" "Select listen section to manage ACLs:" "${items[@]}")

    if [[ -n "$choice" ]]; then
        manage_section_acls "listen:$choice" "$choice"
    fi
}

manage_section_acls() {
    local section="$1"
    local section_name="$2"

    while true; do
        local choice
        choice=$(show_menu "ACL Management: $section_name" \
            "Manage ACLs for $section_name:" \
            "1" "List ACLs" \
            "2" "Add ACL" \
            "3" "Delete ACL" \
            "4" "Add use_backend Rule" \
            "5" "Add http-request Rule" \
            "6" "View All Rules" \
            "0" "Back")

        case "$choice" in
            1) list_acls "$section" "$section_name" ;;
            2) add_acl "$section" "$section_name" ;;
            3) delete_acl "$section" "$section_name" ;;
            4) add_use_backend_rule "$section" "$section_name" ;;
            5) add_http_request_rule "$section" "$section_name" ;;
            6) view_all_rules "$section" "$section_name" ;;
            0|"") return ;;
        esac
    done
}

list_acls() {
    local section="$1"
    local section_name="$2"
    local acls
    acls=$(get_array_directive "$section" "acl")

    if [[ -z "$acls" ]]; then
        show_msgbox "ACLs" "No ACLs defined in $section_name"
        return
    fi

    local temp_file="/tmp/haproxy-gui-acls.$$.txt"
    {
        echo "ACLs in $section_name:"
        echo "======================="
        echo ""
        local index=1
        while IFS= read -r acl; do
            if [[ -n "$acl" ]]; then
                echo "$index. acl $acl"
                ((index++))
            fi
        done <<< "$acls"
    } > "$temp_file"

    show_textbox "ACLs List" "$temp_file"
    rm -f "$temp_file"
}

add_acl() {
    local section="$1"
    local section_name="$2"

    # Show ACL type selection
    local acl_type
    acl_type=$(show_menu "Add ACL" "Select ACL type:" \
        "1" "Path-based (path_beg, path_end)" \
        "2" "Host-based (hdr host)" \
        "3" "Method-based (method)" \
        "4" "IP-based (src)" \
        "5" "Custom Expression" \
        "0" "Cancel")

    case "$acl_type" in
        1) add_path_acl "$section" "$section_name" ;;
        2) add_host_acl "$section" "$section_name" ;;
        3) add_method_acl "$section" "$section_name" ;;
        4) add_ip_acl "$section" "$section_name" ;;
        5) add_custom_acl "$section" "$section_name" ;;
        0|"") return ;;
    esac
}

add_path_acl() {
    local section="$1"
    local section_name="$2"
    local acl_name
    local path

    acl_name=$(show_inputbox "Add Path ACL" "Enter ACL name (e.g., is_api):")
    if [[ -z "$acl_name" ]]; then
        return
    fi

    if ! is_valid_acl_name "$acl_name"; then
        show_msgbox "Error" "Invalid ACL name: $acl_name"
        return
    fi

    path=$(show_inputbox "Add Path ACL" "Enter path to match (e.g., /api):")
    if [[ -z "$path" ]]; then
        return
    fi

    local matcher
    matcher=$(show_radiolist "Path Matcher" "Select path matching method:" \
        "path_beg" "Path begins with" "on" \
        "path_end" "Path ends with" "off" \
        "path_dir" "Path directory" "off" \
        "path_reg" "Path regex" "off")

    if [[ -z "$matcher" ]]; then
        matcher="path_beg"
    fi

    local acl_line="$acl_name $matcher $path"
    if add_array_directive_value "$section" "acl" "$acl_line"; then
        if write_config_file "$CONFIG_FILE" "Added path ACL to $section_name"; then
            show_msgbox "Success" "ACL '$acl_name' added successfully!\n\nYou can now use it in use_backend rules."
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add ACL"
    fi
}

add_host_acl() {
    local section="$1"
    local section_name="$2"
    local acl_name
    local hostname

    acl_name=$(show_inputbox "Add Host ACL" "Enter ACL name (e.g., is_example_com):")
    if [[ -z "$acl_name" ]]; then
        return
    fi

    if ! is_valid_acl_name "$acl_name"; then
        show_msgbox "Error" "Invalid ACL name: $acl_name"
        return
    fi

    hostname=$(show_inputbox "Add Host ACL" "Enter hostname to match (e.g., example.com):")
    if [[ -z "$hostname" ]]; then
        return
    fi

    local matcher
    matcher=$(show_radiolist "Host Matcher" "Select host matching method:" \
        "hdr(host) -i" "Host equals (case insensitive)" "on" \
        "hdr_beg(host) -i" "Host begins with" "off" \
        "hdr_end(host) -i" "Host ends with" "off" \
        "hdr_reg(host) -i" "Host regex" "off")

    if [[ -z "$matcher" ]]; then
        matcher="hdr(host) -i"
    fi

    local acl_line="$acl_name $matcher $hostname"
    if add_array_directive_value "$section" "acl" "$acl_line"; then
        if write_config_file "$CONFIG_FILE" "Added host ACL to $section_name"; then
            show_msgbox "Success" "ACL '$acl_name' added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add ACL"
    fi
}

add_method_acl() {
    local section="$1"
    local section_name="$2"
    local acl_name
    local methods

    acl_name=$(show_inputbox "Add Method ACL" "Enter ACL name (e.g., is_post):")
    if [[ -z "$acl_name" ]]; then
        return
    fi

    if ! is_valid_acl_name "$acl_name"; then
        show_msgbox "Error" "Invalid ACL name: $acl_name"
        return
    fi

    methods=$(show_checklist "HTTP Methods" "Select HTTP methods to match:" \
        "GET" "GET requests" "on" \
        "POST" "POST requests" "off" \
        "PUT" "PUT requests" "off" \
        "DELETE" "DELETE requests" "off" \
        "PATCH" "PATCH requests" "off")

    if [[ -z "$methods" ]]; then
        return
    fi

    # Build method list
    local method_list=""
    for method in GET POST PUT DELETE PATCH; do
        if [[ "$methods" =~ $method ]]; then
            method_list="$method_list $method"
        fi
    done

    local acl_line="$acl_name method$method_list"
    if add_array_directive_value "$section" "acl" "$acl_line"; then
        if write_config_file "$CONFIG_FILE" "Added method ACL to $section_name"; then
            show_msgbox "Success" "ACL '$acl_name' added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add ACL"
    fi
}

add_ip_acl() {
    local section="$1"
    local section_name="$2"
    local acl_name
    local ip_range

    acl_name=$(show_inputbox "Add IP ACL" "Enter ACL name (e.g., internal_network):")
    if [[ -z "$acl_name" ]]; then
        return
    fi

    if ! is_valid_acl_name "$acl_name"; then
        show_msgbox "Error" "Invalid ACL name: $acl_name"
        return
    fi

    ip_range=$(show_inputbox "Add IP ACL" "Enter IP address or CIDR (e.g., 192.168.1.0/24):")
    if [[ -z "$ip_range" ]]; then
        return
    fi

    local acl_line="$acl_name src $ip_range"
    if add_array_directive_value "$section" "acl" "$acl_line"; then
        if write_config_file "$CONFIG_FILE" "Added IP ACL to $section_name"; then
            show_msgbox "Success" "ACL '$acl_name' added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add ACL"
    fi
}

add_custom_acl() {
    local section="$1"
    local section_name="$2"
    local acl_name
    local acl_expression

    acl_name=$(show_inputbox "Add Custom ACL" "Enter ACL name:")
    if [[ -z "$acl_name" ]]; then
        return
    fi

    if ! is_valid_acl_name "$acl_name"; then
        show_msgbox "Error" "Invalid ACL name: $acl_name"
        return
    fi

    acl_expression=$(show_inputbox "Add Custom ACL" "Enter ACL expression (e.g., hdr(X-Custom) -i value):")
    if [[ -z "$acl_expression" ]]; then
        return
    fi

    local acl_line="$acl_name $acl_expression"
    if add_array_directive_value "$section" "acl" "$acl_line"; then
        if write_config_file "$CONFIG_FILE" "Added custom ACL to $section_name"; then
            show_msgbox "Success" "ACL '$acl_name' added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add ACL"
    fi
}

delete_acl() {
    local section="$1"
    local section_name="$2"
    local acls
    acls=$(get_array_directive "$section" "acl")

    if [[ -z "$acls" ]]; then
        show_msgbox "Info" "No ACLs to delete in $section_name"
        return
    fi

    # Build menu items
    local items=()
    local index=0
    while IFS= read -r acl; do
        if [[ -n "$acl" ]]; then
            items+=("$index" "$acl")
            ((index++))
        fi
    done <<< "$acls"

    local choice
    choice=$(show_menu "Delete ACL" "Select ACL to delete from '$section_name':" "${items[@]}")

    if [[ -n "$choice" ]]; then
        if show_yesno "Confirm Delete" "Are you sure you want to delete this ACL?"; then
            if delete_array_directive_value "$section" "acl" "$choice"; then
                if write_config_file "$CONFIG_FILE" "Deleted ACL from $section_name"; then
                    show_msgbox "Success" "ACL deleted successfully!"
                else
                    show_msgbox "Error" "Failed to write configuration"
                fi
            else
                show_msgbox "Error" "Failed to delete ACL"
            fi
        fi
    fi
}

add_use_backend_rule() {
    local section="$1"
    local section_name="$2"
    local backend_name
    local acl_condition

    # Get backend name
    backend_name=$(show_inputbox "Add use_backend Rule" "Enter backend name:")
    if [[ -z "$backend_name" ]]; then
        return
    fi

    # Get ACL condition
    acl_condition=$(show_inputbox "Add use_backend Rule" "Enter ACL condition (e.g., is_api or 'is_api is_post'):")
    if [[ -z "$acl_condition" ]]; then
        return
    fi

    local rule="$backend_name if $acl_condition"
    if add_array_directive_value "$section" "use_backend" "$rule"; then
        if write_config_file "$CONFIG_FILE" "Added use_backend rule to $section_name"; then
            show_msgbox "Success" "use_backend rule added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add use_backend rule"
    fi
}

add_http_request_rule() {
    local section="$1"
    local section_name="$2"

    local action
    action=$(show_menu "HTTP Request Rule" "Select action:" \
        "1" "Deny (return 403)" \
        "2" "Redirect" \
        "3" "Add Header" \
        "4" "Set Header" \
        "5" "Delete Header" \
        "0" "Cancel")

    case "$action" in
        1) add_http_deny_rule "$section" "$section_name" ;;
        2) add_http_redirect_rule "$section" "$section_name" ;;
        3) add_http_add_header_rule "$section" "$section_name" ;;
        4) add_http_set_header_rule "$section" "$section_name" ;;
        5) add_http_del_header_rule "$section" "$section_name" ;;
        0|"") return ;;
    esac
}

add_http_deny_rule() {
    local section="$1"
    local section_name="$2"
    local acl_condition

    acl_condition=$(show_inputbox "HTTP Deny Rule" "Enter ACL condition (leave empty for unconditional deny):")

    local rule="deny"
    if [[ -n "$acl_condition" ]]; then
        rule="$rule if $acl_condition"
    fi

    if add_array_directive_value "$section" "http-request" "$rule"; then
        if write_config_file "$CONFIG_FILE" "Added http-request deny rule to $section_name"; then
            show_msgbox "Success" "HTTP deny rule added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add HTTP deny rule"
    fi
}

add_http_redirect_rule() {
    local section="$1"
    local section_name="$2"
    local location
    local acl_condition

    location=$(show_inputbox "HTTP Redirect" "Enter redirect location (e.g., https://example.com or location /new):")
    if [[ -z "$location" ]]; then
        return
    fi

    acl_condition=$(show_inputbox "HTTP Redirect" "Enter ACL condition (leave empty for unconditional):")

    local rule="redirect $location"
    if [[ -n "$acl_condition" ]]; then
        rule="$rule if $acl_condition"
    fi

    if add_array_directive_value "$section" "http-request" "$rule"; then
        if write_config_file "$CONFIG_FILE" "Added http-request redirect rule to $section_name"; then
            show_msgbox "Success" "HTTP redirect rule added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add HTTP redirect rule"
    fi
}

add_http_add_header_rule() {
    local section="$1"
    local section_name="$2"
    local header_name
    local header_value
    local acl_condition

    header_name=$(show_inputbox "Add Header" "Enter header name (e.g., X-Forwarded-Proto):")
    if [[ -z "$header_name" ]]; then
        return
    fi

    header_value=$(show_inputbox "Add Header" "Enter header value (e.g., https):")
    if [[ -z "$header_value" ]]; then
        return
    fi

    acl_condition=$(show_inputbox "Add Header" "Enter ACL condition (leave empty for always add):")

    local rule="add-header $header_name $header_value"
    if [[ -n "$acl_condition" ]]; then
        rule="$rule if $acl_condition"
    fi

    if add_array_directive_value "$section" "http-request" "$rule"; then
        if write_config_file "$CONFIG_FILE" "Added http-request add-header rule to $section_name"; then
            show_msgbox "Success" "HTTP add-header rule added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add HTTP add-header rule"
    fi
}

add_http_set_header_rule() {
    local section="$1"
    local section_name="$2"
    local header_name
    local header_value
    local acl_condition

    header_name=$(show_inputbox "Set Header" "Enter header name (e.g., Host):")
    if [[ -z "$header_name" ]]; then
        return
    fi

    header_value=$(show_inputbox "Set Header" "Enter header value:")
    if [[ -z "$header_value" ]]; then
        return
    fi

    acl_condition=$(show_inputbox "Set Header" "Enter ACL condition (leave empty for always set):")

    local rule="set-header $header_name $header_value"
    if [[ -n "$acl_condition" ]]; then
        rule="$rule if $acl_condition"
    fi

    if add_array_directive_value "$section" "http-request" "$rule"; then
        if write_config_file "$CONFIG_FILE" "Added http-request set-header rule to $section_name"; then
            show_msgbox "Success" "HTTP set-header rule added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add HTTP set-header rule"
    fi
}

add_http_del_header_rule() {
    local section="$1"
    local section_name="$2"
    local header_name
    local acl_condition

    header_name=$(show_inputbox "Delete Header" "Enter header name to delete:")
    if [[ -z "$header_name" ]]; then
        return
    fi

    acl_condition=$(show_inputbox "Delete Header" "Enter ACL condition (leave empty for always delete):")

    local rule="del-header $header_name"
    if [[ -n "$acl_condition" ]]; then
        rule="$rule if $acl_condition"
    fi

    if add_array_directive_value "$section" "http-request" "$rule"; then
        if write_config_file "$CONFIG_FILE" "Added http-request del-header rule to $section_name"; then
            show_msgbox "Success" "HTTP del-header rule added successfully!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add HTTP del-header rule"
    fi
}

view_all_rules() {
    local section="$1"
    local section_name="$2"

    local temp_file="/tmp/haproxy-gui-rules.$$.txt"
    {
        echo "ACLs and Rules in $section_name:"
        echo "=================================="
        echo ""

        echo "=== ACLs ==="
        local acls
        acls=$(get_array_directive "$section" "acl")
        if [[ -n "$acls" ]]; then
            while IFS= read -r acl; do
                if [[ -n "$acl" ]]; then
                    echo "  acl $acl"
                fi
            done <<< "$acls"
        else
            echo "  (none)"
        fi
        echo ""

        echo "=== use_backend Rules ==="
        local use_backend_rules
        use_backend_rules=$(get_array_directive "$section" "use_backend")
        if [[ -n "$use_backend_rules" ]]; then
            while IFS= read -r rule; do
                if [[ -n "$rule" ]]; then
                    echo "  use_backend $rule"
                fi
            done <<< "$use_backend_rules"
        else
            echo "  (none)"
        fi
        echo ""

        echo "=== http-request Rules ==="
        local http_rules
        http_rules=$(get_array_directive "$section" "http-request")
        if [[ -n "$http_rules" ]]; then
            while IFS= read -r rule; do
                if [[ -n "$rule" ]]; then
                    echo "  http-request $rule"
                fi
            done <<< "$http_rules"
        else
            echo "  (none)"
        fi
    } > "$temp_file"

    show_textbox "ACLs and Rules: $section_name" "$temp_file"
    rm -f "$temp_file"
}

acl_templates_library() {
    local choice
    choice=$(show_menu "ACL Templates Library" \
        "Select a template to view:" \
        "1" "API Path Routing" \
        "2" "Subdomain Routing" \
        "3" "IP Whitelist" \
        "4" "SSL Redirect" \
        "5" "Method Filtering" \
        "0" "Back")

    case "$choice" in
        1) show_template_api_routing ;;
        2) show_template_subdomain ;;
        3) show_template_ip_whitelist ;;
        4) show_template_ssl_redirect ;;
        5) show_template_method_filter ;;
        0|"") return ;;
    esac
}

show_template_api_routing() {
    show_msgbox "API Path Routing Template" \
"Example ACLs for routing API requests:

acl is_api path_beg /api
acl is_v1 path_beg /api/v1
acl is_v2 path_beg /api/v2

use_backend api_v2 if is_v2
use_backend api_v1 if is_v1
use_backend api_default if is_api"
}

show_template_subdomain() {
    show_msgbox "Subdomain Routing Template" \
"Example ACLs for subdomain routing:

acl host_api hdr(host) -i api.example.com
acl host_www hdr(host) -i www.example.com
acl host_admin hdr(host) -i admin.example.com

use_backend api_servers if host_api
use_backend www_servers if host_www
use_backend admin_servers if host_admin"
}

show_template_ip_whitelist() {
    show_msgbox "IP Whitelist Template" \
"Example ACLs for IP whitelisting:

acl internal_network src 192.168.0.0/16
acl office_network src 10.0.0.0/8
acl vpn_users src 172.16.0.0/12

acl is_admin path_beg /admin

http-request deny if is_admin !internal_network !office_network !vpn_users"
}

show_template_ssl_redirect() {
    show_msgbox "SSL Redirect Template" \
"Example ACLs for forcing HTTPS:

acl is_ssl dst_port 443
acl is_ssl ssl_fc

http-request redirect scheme https code 301 if !is_ssl"
}

show_template_method_filter() {
    show_msgbox "Method Filtering Template" \
"Example ACLs for HTTP method filtering:

acl is_read method GET HEAD OPTIONS
acl is_write method POST PUT DELETE PATCH

acl is_api path_beg /api
acl authenticated hdr(Authorization) -m found

http-request deny if is_write !authenticated
http-request allow if is_read"
}

test_acl_expression() {
    show_msgbox "ACL Expression Testing" \
"To test ACL expressions:

1. Add the ACL to your configuration
2. Reload HAProxy
3. Test with real requests
4. Check HAProxy logs for matching

Common ACL expressions:
- path_beg /api
- hdr(host) -i example.com
- src 192.168.1.0/24
- method GET POST
- hdr(X-Custom) -m found"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SSL/TLS Configuration Module
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_ssl_tls() {
    while true; do
        local choice
        choice=$(show_menu "SSL/TLS Configuration" \
            "Manage SSL/TLS settings:" \
            "1" "Frontend SSL (Termination)" \
            "2" "Backend SSL" \
            "3" "Certificate Management" \
            "4" "SSL Global Settings" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) menu_frontend_ssl ;;
            2) menu_backend_ssl ;;
            3) menu_certificate_management ;;
            4) menu_ssl_global_settings ;;
            0|"") return ;;
        esac
    done
}

menu_frontend_ssl() {
    local frontends
    frontends=$(get_section_names "frontend")

    if [[ -z "$frontends" ]]; then
        show_msgbox "Info" "No frontends defined. Create a frontend first."
        return
    fi

    # Build menu items
    local items=()
    for frontend in $frontends; do
        items+=("$frontend" "")
    done

    local choice
    choice=$(show_menu "Select Frontend" "Select frontend for SSL configuration:" "${items[@]}")

    if [[ -n "$choice" ]]; then
        configure_frontend_ssl "$choice"
    fi
}

configure_frontend_ssl() {
    local frontend_name="$1"

    while true; do
        local choice
        choice=$(show_menu "Frontend SSL: $frontend_name" \
            "Configure SSL termination:" \
            "1" "Add SSL Bind" \
            "2" "Configure SSL Options" \
            "3" "Set TLS Version" \
            "4" "Configure Ciphers" \
            "5" "Enable HTTP/2 (ALPN)" \
            "6" "Client Certificate Auth" \
            "7" "View SSL Configuration" \
            "0" "Back")

        case "$choice" in
            1) add_ssl_bind "$frontend_name" ;;
            2) configure_ssl_options "$frontend_name" ;;
            3) set_tls_version "$frontend_name" ;;
            4) configure_ciphers "$frontend_name" ;;
            5) enable_http2 "$frontend_name" ;;
            6) configure_client_cert "$frontend_name" ;;
            7) view_ssl_config "$frontend_name" ;;
            0|"") return ;;
        esac
    done
}

add_ssl_bind() {
    local frontend_name="$1"
    local bind_address
    local cert_file

    bind_address=$(show_inputbox "Add SSL Bind" "Enter bind address (e.g., *:443):")
    if [[ -z "$bind_address" ]]; then
        return
    fi

    cert_file=$(show_inputbox "Add SSL Bind" "Enter certificate file path (e.g., /etc/ssl/certs/example.pem):")
    if [[ -z "$cert_file" ]]; then
        return
    fi

    local ssl_bind="$bind_address ssl crt $cert_file"

    if add_array_directive_value "frontend:$frontend_name" "bind" "$ssl_bind"; then
        if write_config_file "$CONFIG_FILE" "Added SSL bind to frontend $frontend_name"; then
            show_msgbox "Success" "SSL bind added successfully!\n\nBind: $bind_address\nCertificate: $cert_file"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to add SSL bind"
    fi
}

configure_ssl_options() {
    local frontend_name="$1"

    local options
    options=$(show_checklist "SSL Options" "Select SSL options:" \
        "no-sslv3" "Disable SSLv3" "on" \
        "no-tlsv10" "Disable TLS 1.0" "on" \
        "no-tlsv11" "Disable TLS 1.1" "on" \
        "no-tls-tickets" "Disable TLS session tickets" "off")

    if [[ -z "$options" ]]; then
        return
    fi

    # Build options string
    local ssl_options=""
    for opt in no-sslv3 no-tlsv10 no-tlsv11 no-tls-tickets; do
        if [[ "$options" =~ $opt ]]; then
            ssl_options="$ssl_options $opt"
        fi
    done

    if set_directive "frontend:$frontend_name" "ssl-default-bind-options" "$ssl_options"; then
        if write_config_file "$CONFIG_FILE" "Set SSL options in frontend $frontend_name"; then
            show_msgbox "Success" "SSL options configured!"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to set SSL options"
    fi
}

set_tls_version() {
    local frontend_name="$1"
    local min_version

    min_version=$(show_radiolist "TLS Version" "Select minimum TLS version:" \
        "TLSv1.2" "TLS 1.2 (recommended)" "on" \
        "TLSv1.3" "TLS 1.3 (most secure)" "off" \
        "TLSv1.1" "TLS 1.1 (legacy)" "off")

    if [[ -z "$min_version" ]]; then
        return
    fi

    if set_directive "frontend:$frontend_name" "ssl-default-bind-min-ver" "$min_version"; then
        if write_config_file "$CONFIG_FILE" "Set TLS version in frontend $frontend_name"; then
            show_msgbox "Success" "Minimum TLS version set to $min_version"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to set TLS version"
    fi
}

configure_ciphers() {
    local frontend_name="$1"
    local cipher_suite

    cipher_suite=$(show_radiolist "Cipher Suites" "Select cipher suite:" \
        "modern" "Modern (TLS 1.3+ only)" "off" \
        "intermediate" "Intermediate (recommended)" "on" \
        "old" "Old (legacy support)" "off")

    local ciphers
    case "$cipher_suite" in
        modern)
            ciphers="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
            ;;
        intermediate)
            ciphers="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384"
            ;;
        old)
            ciphers="ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA"
            ;;
        *)
            return
            ;;
    esac

    if set_directive "frontend:$frontend_name" "ssl-default-bind-ciphers" "$ciphers"; then
        if write_config_file "$CONFIG_FILE" "Set cipher suite in frontend $frontend_name"; then
            show_msgbox "Success" "Cipher suite configured: $cipher_suite"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to set cipher suite"
    fi
}

enable_http2() {
    local frontend_name="$1"

    if show_yesno "Enable HTTP/2" "Enable HTTP/2 (ALPN) for this frontend?\n\nRequires SSL/TLS to be configured."; then
        if set_directive "frontend:$frontend_name" "bind-process" "alpn h2,http/1.1"; then
            if write_config_file "$CONFIG_FILE" "Enabled HTTP/2 in frontend $frontend_name"; then
                show_msgbox "Success" "HTTP/2 (ALPN) enabled!\n\nNote: Requires HAProxy 1.8+"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to enable HTTP/2"
        fi
    fi
}

configure_client_cert() {
    local frontend_name="$1"
    local ca_file

    ca_file=$(show_inputbox "Client Certificate Auth" "Enter CA file path for client verification:")
    if [[ -z "$ca_file" ]]; then
        return
    fi

    local verify_mode
    verify_mode=$(show_radiolist "Verify Mode" "Select verification mode:" \
        "required" "Required (strict)" "on" \
        "optional" "Optional" "off")

    if [[ -z "$verify_mode" ]]; then
        verify_mode="required"
    fi

    # Update all SSL binds to include client verification
    show_msgbox "Info" "Client certificate verification configured.\n\nYou'll need to manually update bind lines to include:\nca-file $ca_file verify $verify_mode"
}

view_ssl_config() {
    local frontend_name="$1"
    local temp_file="/tmp/haproxy-gui-ssl-config.$$.txt"

    {
        echo "SSL Configuration for Frontend: $frontend_name"
        echo "================================================"
        echo ""

        echo "=== Bind Addresses ==="
        local binds
        binds=$(get_array_directive "frontend:$frontend_name" "bind")
        if [[ -n "$binds" ]]; then
            while IFS= read -r bind; do
                if [[ -n "$bind" ]]; then
                    echo "  bind $bind"
                fi
            done <<< "$binds"
        else
            echo "  (none)"
        fi
        echo ""

        echo "=== SSL Options ==="
        local ssl_opts
        ssl_opts=$(get_directive "frontend:$frontend_name" "ssl-default-bind-options")
        echo "  Options: ${ssl_opts:-(none)}"

        local tls_ver
        tls_ver=$(get_directive "frontend:$frontend_name" "ssl-default-bind-min-ver")
        echo "  Min TLS Version: ${tls_ver:-(default)}"

        local ciphers
        ciphers=$(get_directive "frontend:$frontend_name" "ssl-default-bind-ciphers")
        echo "  Ciphers: ${ciphers:-(default)}"
    } > "$temp_file"

    show_textbox "SSL Configuration" "$temp_file"
    rm -f "$temp_file"
}

menu_backend_ssl() {
    local backends
    backends=$(get_section_names "backend")

    if [[ -z "$backends" ]]; then
        show_msgbox "Info" "No backends defined. Create a backend first."
        return
    fi

    # Build menu items
    local items=()
    for backend in $backends; do
        items+=("$backend" "")
    done

    local choice
    choice=$(show_menu "Select Backend" "Select backend for SSL configuration:" "${items[@]}")

    if [[ -n "$choice" ]]; then
        configure_backend_ssl "$choice"
    fi
}

configure_backend_ssl() {
    local backend_name="$1"

    show_msgbox "Backend SSL" \
"To enable SSL to backend servers:

1. Add 'ssl' option to server lines
2. Add 'verify none' to skip verification
   or 'verify required ca-file /path' for strict verification

Example:
  server web1 192.168.1.10:443 ssl verify none
  server web2 192.168.1.11:443 ssl verify required ca-file /etc/ssl/ca.pem

Use 'Edit Backend' > 'Manage Servers' to add/edit servers with SSL."
}

menu_certificate_management() {
    while true; do
        local choice
        choice=$(show_menu "Certificate Management" \
            "Manage SSL certificates:" \
            "1" "List Certificate Files" \
            "2" "View Certificate Info" \
            "3" "Certificate Paths Help" \
            "0" "Back")

        case "$choice" in
            1) list_certificate_files ;;
            2) view_certificate_info ;;
            3) show_certificate_paths_help ;;
            0|"") return ;;
        esac
    done
}

list_certificate_files() {
    show_msgbox "Certificate Files" \
"Common certificate locations:

/etc/ssl/certs/          - System certificates
/etc/haproxy/certs/      - HAProxy certificates
/etc/letsencrypt/live/   - Let's Encrypt certificates

HAProxy requires PEM format combining:
  - Certificate
  - Private key
  - Optional chain/intermediate

To create a combined PEM:
  cat cert.crt key.key > combined.pem"
}

view_certificate_info() {
    local cert_file

    cert_file=$(show_inputbox "View Certificate" "Enter certificate file path:")
    if [[ -z "$cert_file" ]]; then
        return
    fi

    if [[ ! -f "$cert_file" ]]; then
        show_msgbox "Error" "Certificate file not found: $cert_file"
        return
    fi

    local temp_file="/tmp/haproxy-gui-cert-info.$$.txt"
    openssl x509 -in "$cert_file" -text -noout > "$temp_file" 2>&1 || {
        show_msgbox "Error" "Failed to read certificate. Ensure it's in PEM format."
        rm -f "$temp_file"
        return
    }

    show_textbox "Certificate Info" "$temp_file"
    rm -f "$temp_file"
}

show_certificate_paths_help() {
    show_msgbox "Certificate Paths" \
"HAProxy Certificate Requirements:

1. Format: PEM (Base64 encoded)
2. Must contain: Private key + Certificate
3. Optional: Intermediate/chain certificates

Creating combined PEM:
  cat server.crt server.key > server.pem

Let's Encrypt:
  cat /etc/letsencrypt/live/domain/fullchain.pem \\
      /etc/letsencrypt/live/domain/privkey.pem > haproxy.pem

Permissions:
  chmod 600 /path/to/cert.pem
  chown haproxy:haproxy /path/to/cert.pem"
}

menu_ssl_global_settings() {
    while true; do
        local choice
        choice=$(show_menu "SSL Global Settings" \
            "Global SSL configuration:" \
            "1" "Set DH Parameters" \
            "2" "Set SSL Engine" \
            "3" "Configure SSL Cache" \
            "4" "View Current Settings" \
            "0" "Back")

        case "$choice" in
            1) set_dh_parameters ;;
            2) set_ssl_engine ;;
            3) configure_ssl_cache ;;
            4) view_ssl_global_settings ;;
            0|"") return ;;
        esac
    done
}

set_dh_parameters() {
    local dh_size

    dh_size=$(show_radiolist "DH Parameters" "Select DH parameter size:" \
        "2048" "2048 bits (standard)" "on" \
        "4096" "4096 bits (more secure, slower)" "off")

    if [[ -z "$dh_size" ]]; then
        return
    fi

    if set_directive "global" "tune.ssl.default-dh-param" "$dh_size"; then
        if write_config_file "$CONFIG_FILE" "Set DH parameters size"; then
            show_msgbox "Success" "DH parameter size set to $dh_size bits"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to set DH parameters"
    fi
}

set_ssl_engine() {
    local engine

    engine=$(show_inputbox "SSL Engine" "Enter SSL engine name (or leave empty for default):")

    if [[ -n "$engine" ]]; then
        if set_directive "global" "ssl-engine" "$engine"; then
            if write_config_file "$CONFIG_FILE" "Set SSL engine"; then
                show_msgbox "Success" "SSL engine set to $engine"
            else
                show_msgbox "Error" "Failed to write configuration"
            fi
        else
            show_msgbox "Error" "Failed to set SSL engine"
        fi
    fi
}

configure_ssl_cache() {
    local cache_size

    cache_size=$(show_inputbox "SSL Cache" "Enter SSL session cache size (e.g., 20000):" "20000")
    if [[ -z "$cache_size" ]]; then
        return
    fi

    if ! [[ "$cache_size" =~ ^[0-9]+$ ]]; then
        show_msgbox "Error" "Invalid cache size: $cache_size"
        return
    fi

    if set_directive "global" "tune.ssl.cachesize" "$cache_size"; then
        if write_config_file "$CONFIG_FILE" "Set SSL cache size"; then
            show_msgbox "Success" "SSL cache size set to $cache_size"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to set SSL cache"
    fi
}

view_ssl_global_settings() {
    local temp_file="/tmp/haproxy-gui-ssl-global.$$.txt"

    {
        echo "SSL Global Settings"
        echo "==================="
        echo ""

        local dh_param
        dh_param=$(get_directive "global" "tune.ssl.default-dh-param")
        echo "DH Parameters: ${dh_param:-(default)}"

        local ssl_engine
        ssl_engine=$(get_directive "global" "ssl-engine")
        echo "SSL Engine: ${ssl_engine:-(default)}"

        local cache_size
        cache_size=$(get_directive "global" "tune.ssl.cachesize")
        echo "SSL Cache Size: ${cache_size:-(default)}"
    } > "$temp_file"

    show_textbox "SSL Global Settings" "$temp_file"
    rm -f "$temp_file"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Global Settings Menu
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_global_settings() {
    while true; do
        local choice
        choice=$(show_menu "Global Settings" \
            "Manage global HAProxy settings:" \
            "1" "View Global Settings" \
            "2" "Edit Max Connections" \
            "3" "Edit User/Group" \
            "4" "Edit Daemon Mode" \
            "5" "Edit Threads (nbthread)" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) view_global_settings ;;
            2) edit_global_maxconn ;;
            3) edit_global_user_group ;;
            4) edit_global_daemon ;;
            5) edit_global_nbthread ;;
            0|"") return ;;
        esac
    done
}

view_global_settings() {
    local temp_file="/tmp/haproxy-gui-global.$$.txt"

    if section_exists "global"; then
        display_section "global" > "$temp_file"
    else
        echo "Global section not found in configuration" > "$temp_file"
    fi

    show_textbox "Global Settings" "$temp_file"
    rm -f "$temp_file"
}

edit_global_maxconn() {
    local current_value
    current_value=$(get_directive "global" "maxconn")

    local new_value
    new_value=$(show_inputbox "Edit Max Connections" \
        "Enter maximum concurrent connections:" \
        "${current_value:-4096}")

    if [[ -z "$new_value" ]]; then
        return
    fi

    # Validate it's a number
    if ! [[ "$new_value" =~ ^[0-9]+$ ]]; then
        show_msgbox "Error" "Invalid value: must be a number"
        return
    fi

    # Ensure global section exists
    if ! section_exists "global"; then
        SECTION_LIST=("global" "${SECTION_LIST[@]}")
        CONFIG_ORDER["global"]=0
    fi

    if set_directive "global" "maxconn" "$new_value"; then
        if write_config_file "$CONFIG_FILE" "Updated global maxconn to $new_value"; then
            show_msgbox "Success" "Max connections set to $new_value"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to update maxconn"
    fi
}

edit_global_user_group() {
    local current_user
    local current_group
    current_user=$(get_directive "global" "user")
    current_group=$(get_directive "global" "group")

    local new_user
    local new_group

    new_user=$(show_inputbox "Edit User" \
        "Enter user to run HAProxy as:" \
        "${current_user:-haproxy}")

    if [[ -z "$new_user" ]]; then
        return
    fi

    new_group=$(show_inputbox "Edit Group" \
        "Enter group to run HAProxy as:" \
        "${current_group:-haproxy}")

    if [[ -z "$new_group" ]]; then
        return
    fi

    # Ensure global section exists
    if ! section_exists "global"; then
        SECTION_LIST=("global" "${SECTION_LIST[@]}")
        CONFIG_ORDER["global"]=0
    fi

    set_directive "global" "user" "$new_user"
    set_directive "global" "group" "$new_group"

    if write_config_file "$CONFIG_FILE" "Updated global user/group to $new_user:$new_group"; then
        show_msgbox "Success" "User/Group set to $new_user:$new_group"
    else
        show_msgbox "Error" "Failed to write configuration"
    fi
}

edit_global_daemon() {
    local has_daemon
    has_daemon=$(get_directive "global" "daemon")

    local choice
    if [[ -n "$has_daemon" ]]; then
        choice=$(show_radiolist "Daemon Mode" \
            "Run HAProxy as daemon?" \
            "yes" "Run as daemon (background)" "on" \
            "no" "Run in foreground" "off")
    else
        choice=$(show_radiolist "Daemon Mode" \
            "Run HAProxy as daemon?" \
            "yes" "Run as daemon (background)" "off" \
            "no" "Run in foreground" "on")
    fi

    if [[ -z "$choice" ]]; then
        return
    fi

    # Ensure global section exists
    if ! section_exists "global"; then
        SECTION_LIST=("global" "${SECTION_LIST[@]}")
        CONFIG_ORDER["global"]=0
    fi

    if [[ "$choice" == "yes" ]]; then
        set_directive "global" "daemon" ""
        local msg="enabled"
    else
        delete_directive "global" "daemon"
        local msg="disabled"
    fi

    if write_config_file "$CONFIG_FILE" "Updated global daemon mode"; then
        show_msgbox "Success" "Daemon mode $msg"
    else
        show_msgbox "Error" "Failed to write configuration"
    fi
}

edit_global_nbthread() {
    local current_value
    current_value=$(get_directive "global" "nbthread")

    local new_value
    new_value=$(show_inputbox "Edit Thread Count" \
        "Enter number of threads (nbthread):" \
        "${current_value:-4}")

    if [[ -z "$new_value" ]]; then
        return
    fi

    # Validate it's a number
    if ! [[ "$new_value" =~ ^[0-9]+$ ]]; then
        show_msgbox "Error" "Invalid value: must be a number"
        return
    fi

    # Ensure global section exists
    if ! section_exists "global"; then
        SECTION_LIST=("global" "${SECTION_LIST[@]}")
        CONFIG_ORDER["global"]=0
    fi

    if set_directive "global" "nbthread" "$new_value"; then
        if write_config_file "$CONFIG_FILE" "Updated global nbthread to $new_value"; then
            show_msgbox "Success" "Thread count set to $new_value"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to update nbthread"
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Defaults Settings Menu
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_defaults_settings() {
    while true; do
        local choice
        choice=$(show_menu "Defaults Settings" \
            "Manage default HAProxy settings:" \
            "1" "View Defaults Settings" \
            "2" "Edit Mode" \
            "3" "Edit Timeouts" \
            "4" "Edit Retries" \
            "5" "Edit Balance Algorithm" \
            "6" "Manage Options" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) view_defaults_settings ;;
            2) edit_defaults_mode ;;
            3) edit_defaults_timeouts ;;
            4) edit_defaults_retries ;;
            5) edit_defaults_balance ;;
            6) manage_defaults_options ;;
            0|"") return ;;
        esac
    done
}

view_defaults_settings() {
    local temp_file="/tmp/haproxy-gui-defaults.$$.txt"

    if section_exists "defaults"; then
        display_section "defaults" > "$temp_file"
    else
        echo "Defaults section not found in configuration" > "$temp_file"
    fi

    show_textbox "Defaults Settings" "$temp_file"
    rm -f "$temp_file"
}

edit_defaults_mode() {
    local current_mode
    current_mode=$(get_directive "defaults" "mode")

    local new_mode
    new_mode=$(show_radiolist "Change Default Mode" \
        "Select default mode:" \
        "http" "HTTP mode (layer 7)" "$([ "$current_mode" = "http" ] && echo "on" || echo "off")" \
        "tcp" "TCP mode (layer 4)" "$([ "$current_mode" = "tcp" ] && echo "on" || echo "off")")

    if [[ -z "$new_mode" ]]; then
        return
    fi

    # Ensure defaults section exists
    if ! section_exists "defaults"; then
        # Insert defaults after global
        if section_exists "global"; then
            SECTION_LIST=("global" "defaults" "${SECTION_LIST[@]:1}")
        else
            SECTION_LIST=("defaults" "${SECTION_LIST[@]}")
        fi
        CONFIG_ORDER["defaults"]=1
    fi

    if set_directive "defaults" "mode" "$new_mode"; then
        if write_config_file "$CONFIG_FILE" "Updated defaults mode to $new_mode"; then
            show_msgbox "Success" "Default mode set to $new_mode"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to update mode"
    fi
}

edit_defaults_timeouts() {
    while true; do
        local choice
        choice=$(show_menu "Edit Timeouts" \
            "Select timeout to edit:" \
            "1" "Timeout Connect" \
            "2" "Timeout Client" \
            "3" "Timeout Server" \
            "4" "Timeout Check" \
            "5" "Timeout HTTP-Request" \
            "6" "Timeout HTTP-Keep-Alive" \
            "0" "Back")

        case "$choice" in
            1) edit_timeout "connect" "5000ms" ;;
            2) edit_timeout "client" "50000ms" ;;
            3) edit_timeout "server" "50000ms" ;;
            4) edit_timeout "check" "10s" ;;
            5) edit_timeout "http-request" "10s" ;;
            6) edit_timeout "http-keep-alive" "10s" ;;
            0|"") return ;;
        esac
    done
}

edit_timeout() {
    local timeout_name="$1"
    local default_value="$2"
    local directive="timeout $timeout_name"

    local current_value
    current_value=$(get_directive "defaults" "timeout $timeout_name")

    local new_value
    new_value=$(show_inputbox "Edit Timeout $timeout_name" \
        "Enter timeout value (e.g., 5000ms, 10s, 1m):" \
        "${current_value:-$default_value}")

    if [[ -z "$new_value" ]]; then
        return
    fi

    # Validate timeout format
    if ! is_valid_timeout "$new_value"; then
        show_msgbox "Error" "Invalid timeout format. Use: <number>[ms|s|m|h|d]"
        return
    fi

    # Ensure defaults section exists
    if ! section_exists "defaults"; then
        if section_exists "global"; then
            SECTION_LIST=("global" "defaults" "${SECTION_LIST[@]:1}")
        else
            SECTION_LIST=("defaults" "${SECTION_LIST[@]}")
        fi
        CONFIG_ORDER["defaults"]=1
    fi

    if set_directive "defaults" "timeout $timeout_name" "$new_value"; then
        if write_config_file "$CONFIG_FILE" "Updated defaults timeout $timeout_name to $new_value"; then
            show_msgbox "Success" "Timeout $timeout_name set to $new_value"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to update timeout"
    fi
}

edit_defaults_retries() {
    local current_value
    current_value=$(get_directive "defaults" "retries")

    local new_value
    new_value=$(show_inputbox "Edit Retries" \
        "Enter number of connection retries:" \
        "${current_value:-3}")

    if [[ -z "$new_value" ]]; then
        return
    fi

    # Validate it's a number
    if ! [[ "$new_value" =~ ^[0-9]+$ ]]; then
        show_msgbox "Error" "Invalid value: must be a number"
        return
    fi

    # Ensure defaults section exists
    if ! section_exists "defaults"; then
        if section_exists "global"; then
            SECTION_LIST=("global" "defaults" "${SECTION_LIST[@]:1}")
        else
            SECTION_LIST=("defaults" "${SECTION_LIST[@]}")
        fi
        CONFIG_ORDER["defaults"]=1
    fi

    if set_directive "defaults" "retries" "$new_value"; then
        if write_config_file "$CONFIG_FILE" "Updated defaults retries to $new_value"; then
            show_msgbox "Success" "Retries set to $new_value"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to update retries"
    fi
}

edit_defaults_balance() {
    local current_balance
    current_balance=$(get_directive "defaults" "balance")

    local new_balance
    new_balance=$(show_radiolist "Change Default Balance Algorithm" \
        "Select default balance algorithm:" \
        "roundrobin" "Round Robin" "$([ "$current_balance" = "roundrobin" ] && echo "on" || echo "off")" \
        "leastconn" "Least Connections" "$([ "$current_balance" = "leastconn" ] && echo "on" || echo "off")" \
        "source" "Source IP Hash" "$([ "$current_balance" = "source" ] && echo "on" || echo "off")")

    if [[ -z "$new_balance" ]]; then
        return
    fi

    # Ensure defaults section exists
    if ! section_exists "defaults"; then
        if section_exists "global"; then
            SECTION_LIST=("global" "defaults" "${SECTION_LIST[@]:1}")
        else
            SECTION_LIST=("defaults" "${SECTION_LIST[@]}")
        fi
        CONFIG_ORDER["defaults"]=1
    fi

    if set_directive "defaults" "balance" "$new_balance"; then
        if write_config_file "$CONFIG_FILE" "Updated defaults balance to $new_balance"; then
            show_msgbox "Success" "Default balance algorithm set to $new_balance"
        else
            show_msgbox "Error" "Failed to write configuration"
        fi
    else
        show_msgbox "Error" "Failed to update balance"
    fi
}

manage_defaults_options() {
    local current_httplog=""
    local current_dontlognull=""
    local current_http_server_close=""
    local current_forwardfor=""
    local current_redispatch=""

    # Check current options
    [[ -n "$(get_directive "defaults" "option httplog")" ]] && current_httplog="on" || current_httplog="off"
    [[ -n "$(get_directive "defaults" "option dontlognull")" ]] && current_dontlognull="on" || current_dontlognull="off"
    [[ -n "$(get_directive "defaults" "option http-server-close")" ]] && current_http_server_close="on" || current_http_server_close="off"
    [[ -n "$(get_directive "defaults" "option forwardfor")" ]] && current_forwardfor="on" || current_forwardfor="off"
    [[ -n "$(get_directive "defaults" "option redispatch")" ]] && current_redispatch="on" || current_redispatch="off"

    local options_choice
    options_choice=$(show_checklist "Manage Default Options" \
        "Select default options to enable:" \
        "httplog" "Enable HTTP logging" "$current_httplog" \
        "dontlognull" "Don't log null connections" "$current_dontlognull" \
        "http-server-close" "HTTP server close" "$current_http_server_close" \
        "forwardfor" "Add X-Forwarded-For header" "$current_forwardfor" \
        "redispatch" "Allow session redistribution" "$current_redispatch")

    # Ensure defaults section exists
    if ! section_exists "defaults"; then
        if section_exists "global"; then
            SECTION_LIST=("global" "defaults" "${SECTION_LIST[@]:1}")
        else
            SECTION_LIST=("defaults" "${SECTION_LIST[@]}")
        fi
        CONFIG_ORDER["defaults"]=1
    fi

    # Update options based on selection
    [[ "$options_choice" =~ "httplog" ]] && set_directive "defaults" "option httplog" "" || delete_directive "defaults" "option httplog"
    [[ "$options_choice" =~ "dontlognull" ]] && set_directive "defaults" "option dontlognull" "" || delete_directive "defaults" "option dontlognull"
    [[ "$options_choice" =~ "http-server-close" ]] && set_directive "defaults" "option http-server-close" "" || delete_directive "defaults" "option http-server-close"
    [[ "$options_choice" =~ "forwardfor" ]] && set_directive "defaults" "option forwardfor" "" || delete_directive "defaults" "option forwardfor"
    [[ "$options_choice" =~ "redispatch" ]] && set_directive "defaults" "option redispatch" "" || delete_directive "defaults" "option redispatch"

    if write_config_file "$CONFIG_FILE" "Updated defaults options"; then
        show_msgbox "Success" "Default options updated successfully"
    else
        show_msgbox "Error" "Failed to write configuration"
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Validation Menu
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_validation() {
    local choice
    choice=$(show_menu "Validation & Testing" \
        "Configuration validation options:" \
        "1" "Validate Current Configuration" \
        "2" "Check Configuration Warnings" \
        "0" "Back to Main Menu")

    case "$choice" in
        1) validate_current_config ;;
        2) check_warnings ;;
        0|"") return ;;
    esac
}

validate_current_config() {
    local temp_file="/tmp/haproxy-gui-validate.$$.txt"

    {
        echo "Validating configuration..."
        echo ""
        if validate_config_file "$CONFIG_FILE"; then
            echo "✓ Configuration validation PASSED"
        else
            echo "✗ Configuration validation FAILED"
            echo ""
            echo "Please check the errors above."
        fi
    } > "$temp_file" 2>&1

    show_textbox "Validation Results" "$temp_file"
    rm -f "$temp_file"
}

check_warnings() {
    local temp_file="/tmp/haproxy-gui-warnings.$$.txt"
    check_config_warnings > "$temp_file" 2>&1
    show_textbox "Configuration Warnings" "$temp_file"
    rm -f "$temp_file"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Service Control Menu
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_service_control() {
    while true; do
        local choice
        choice=$(show_menu "HAProxy Service Control" \
            "Manage HAProxy service:" \
            "1" "Check HAProxy Status" \
            "2" "Validate & Reload HAProxy" \
            "3" "Restart HAProxy" \
            "4" "View HAProxy Version" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) check_haproxy_status ;;
            2) reload_haproxy ;;
            3) restart_haproxy ;;
            4) view_haproxy_version ;;
            0|"") return ;;
        esac
    done
}

check_haproxy_status() {
    local temp_file="/tmp/haproxy-gui-status.$$.txt"

    {
        echo "HAProxy Service Status"
        echo "======================"
        echo ""

        # Check if HAProxy is installed
        if ! command_exists "haproxy"; then
            echo "ERROR: HAProxy command not found"
            echo "Please install HAProxy first."
        else
            # Try systemctl first
            if command_exists "systemctl"; then
                echo "Using systemctl..."
                echo ""
                systemctl status haproxy 2>&1 || true
            elif command_exists "service"; then
                echo "Using service command..."
                echo ""
                service haproxy status 2>&1 || true
            else
                echo "WARNING: No service manager found (systemctl or service)"
                echo ""
                # Try to check if process is running
                if pgrep -x haproxy > /dev/null; then
                    echo "HAProxy process is running (PID: $(pgrep -x haproxy))"
                else
                    echo "HAProxy process is NOT running"
                fi
            fi
        fi
    } > "$temp_file" 2>&1

    show_textbox "HAProxy Status" "$temp_file"
    rm -f "$temp_file"
}

reload_haproxy() {
    # First validate configuration
    if ! validate_config_file "$CONFIG_FILE"; then
        show_msgbox "Validation Failed" "Configuration validation failed!\n\nPlease fix errors before reloading HAProxy.\n\nHAProxy will NOT be reloaded."
        return 1
    fi

    show_msgbox "Validation Passed" "Configuration validation passed!\n\nProceeding with HAProxy reload..."

    local temp_file="/tmp/haproxy-gui-reload.$$.txt"

    {
        echo "HAProxy Reload Operation"
        echo "========================"
        echo ""

        # Check if HAProxy is installed
        if ! command_exists "haproxy"; then
            echo "ERROR: HAProxy command not found"
            echo "Please install HAProxy first."
        elif ! is_root; then
            echo "ERROR: Root privileges required to reload HAProxy"
            echo "Please run this application with sudo"
        else
            # Try systemctl first
            if command_exists "systemctl"; then
                echo "Reloading HAProxy using systemctl..."
                echo ""
                if systemctl reload haproxy 2>&1; then
                    echo ""
                    echo "✓ HAProxy reloaded successfully!"
                else
                    echo ""
                    echo "✗ HAProxy reload failed!"
                fi
            elif command_exists "service"; then
                echo "Reloading HAProxy using service command..."
                echo ""
                if service haproxy reload 2>&1; then
                    echo ""
                    echo "✓ HAProxy reloaded successfully!"
                else
                    echo ""
                    echo "✗ HAProxy reload failed!"
                fi
            else
                echo "ERROR: No service manager found (systemctl or service)"
                echo "Cannot reload HAProxy automatically"
                echo ""
                echo "Manual reload command:"
                echo "  kill -USR2 \$(cat /var/run/haproxy.pid)"
            fi
        fi
    } > "$temp_file" 2>&1

    show_textbox "HAProxy Reload Results" "$temp_file"
    rm -f "$temp_file"
}

restart_haproxy() {
    if ! show_yesno "Confirm Restart" "Are you sure you want to RESTART HAProxy?\n\nThis will briefly interrupt service.\n\nReload is usually preferred over restart."; then
        return
    fi

    # First validate configuration
    if ! validate_config_file "$CONFIG_FILE"; then
        show_msgbox "Validation Failed" "Configuration validation failed!\n\nPlease fix errors before restarting HAProxy.\n\nHAProxy will NOT be restarted."
        return 1
    fi

    local temp_file="/tmp/haproxy-gui-restart.$$.txt"

    {
        echo "HAProxy Restart Operation"
        echo "========================="
        echo ""

        # Check if HAProxy is installed
        if ! command_exists "haproxy"; then
            echo "ERROR: HAProxy command not found"
            echo "Please install HAProxy first."
        elif ! is_root; then
            echo "ERROR: Root privileges required to restart HAProxy"
            echo "Please run this application with sudo"
        else
            # Try systemctl first
            if command_exists "systemctl"; then
                echo "Restarting HAProxy using systemctl..."
                echo ""
                if systemctl restart haproxy 2>&1; then
                    echo ""
                    echo "✓ HAProxy restarted successfully!"
                else
                    echo ""
                    echo "✗ HAProxy restart failed!"
                fi
            elif command_exists "service"; then
                echo "Restarting HAProxy using service command..."
                echo ""
                if service haproxy restart 2>&1; then
                    echo ""
                    echo "✓ HAProxy restarted successfully!"
                else
                    echo ""
                    echo "✗ HAProxy restart failed!"
                fi
            else
                echo "ERROR: No service manager found (systemctl or service)"
                echo "Cannot restart HAProxy automatically"
            fi
        fi
    } > "$temp_file" 2>&1

    show_textbox "HAProxy Restart Results" "$temp_file"
    rm -f "$temp_file"
}

view_haproxy_version() {
    local temp_file="/tmp/haproxy-gui-version.$$.txt"

    {
        echo "HAProxy Version Information"
        echo "==========================="
        echo ""

        if command_exists "haproxy"; then
            haproxy -vv 2>&1
        else
            echo "ERROR: HAProxy command not found"
            echo "Please install HAProxy first."
        fi
    } > "$temp_file" 2>&1

    show_textbox "HAProxy Version" "$temp_file"
    rm -f "$temp_file"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Backup & Restore Menu
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_backup_restore() {
    while true; do
        local choice
        choice=$(show_menu "Backup & Restore" \
            "Manage configuration backups:" \
            "1" "List Backups" \
            "2" "Create Manual Backup" \
            "3" "Restore from Backup" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) show_backups_list ;;
            2) create_manual_backup ;;
            3) restore_from_backup ;;
            0|"") return ;;
        esac
    done
}

show_backups_list() {
    local temp_file="/tmp/haproxy-gui-backups.$$.txt"
    list_backups > "$temp_file"
    show_textbox "Available Backups" "$temp_file"
    rm -f "$temp_file"
}

create_manual_backup() {
    local reason
    reason=$(show_inputbox "Create Backup" "Enter reason for backup:")

    if [[ -z "$reason" ]]; then
        reason="Manual backup"
    fi

    local backup_file
    backup_file=$(create_backup "$CONFIG_FILE" "$reason")

    if [[ $? -eq 0 ]]; then
        show_msgbox "Success" "Backup created successfully!\n\n$(basename "$backup_file")"
    else
        show_msgbox "Error" "Failed to create backup"
    fi
}

restore_from_backup() {
    local backups
    backups=$(find "$BACKUP_DIR" -name "*.backup.*" -type f 2>/dev/null | sort -r)

    if [[ -z "$backups" ]]; then
        show_msgbox "Info" "No backups available"
        return
    fi

    # Build menu items
    local items=()
    while IFS= read -r backup; do
        local basename_file
        basename_file=$(basename "$backup")
        items+=("$backup" "$basename_file")
    done <<< "$backups"

    local choice
    choice=$(show_menu "Restore Backup" "Select backup to restore:" "${items[@]}")

    if [[ -n "$choice" ]]; then
        if show_yesno "Confirm Restore" "Are you sure you want to restore from:\n$(basename "$choice")\n\nCurrent configuration will be backed up first."; then
            if restore_backup "$choice" "$CONFIG_FILE"; then
                # Reload configuration
                parse_config_file "$CONFIG_FILE"
                show_msgbox "Success" "Configuration restored successfully!"
            else
                show_msgbox "Error" "Failed to restore backup"
            fi
        fi
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration File Menu
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_config_file() {
    local choice
    choice=$(show_menu "Configuration File" \
        "Current file: $CONFIG_FILE" \
        "1" "Change Configuration File Path" \
        "2" "Reload Configuration" \
        "0" "Back to Main Menu")

    case "$choice" in
        1) change_config_file ;;
        2) reload_config ;;
        0|"") return ;;
    esac
}

change_config_file() {
    local new_file
    new_file=$(show_inputbox "Change Config File" "Enter new configuration file path:" "$CONFIG_FILE")

    if [[ -n "$new_file" ]] && [[ "$new_file" != "$CONFIG_FILE" ]]; then
        if [[ -f "$new_file" ]]; then
            CONFIG_FILE="$new_file"
            if parse_config_file "$CONFIG_FILE"; then
                show_msgbox "Success" "Configuration file changed to:\n$CONFIG_FILE"
            else
                show_msgbox "Error" "Failed to parse new configuration file"
            fi
        else
            show_msgbox "Error" "File not found: $new_file"
        fi
    fi
}

reload_config() {
    if parse_config_file "$CONFIG_FILE"; then
        show_msgbox "Success" "Configuration reloaded from:\n$CONFIG_FILE"
    else
        show_msgbox "Error" "Failed to reload configuration"
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Help & Exit Menu
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_help_exit() {
    local choice
    choice=$(show_menu "Help & Exit" \
        "Information and exit options:" \
        "1" "About HAProxy CLI GUI" \
        "2" "Quick Help" \
        "3" "Exit Application" \
        "0" "Back to Main Menu")

    case "$choice" in
        1) show_about ;;
        2) show_quick_help ;;
        3) exit_application ;;
        0|"") return ;;
    esac
}

show_about() {
    show_msgbox "HAProxy CLI GUI - About" \
"HAProxy CLI GUI v1.2.0 - Phase 3

A fully interactive bash-based terminal GUI for managing
HAProxy configuration files.

CRITICAL FEATURE:
Every configuration modification automatically creates a
full backup file before making changes.

Current Features:
- Frontend & Backend Management (FULL)
- Server Management (Add/Edit/Delete)
- Bind Address Management
- Global Settings (maxconn, user/group, daemon, threads)
- Defaults Settings (timeouts, mode, options, balance)
- Service Control (Reload/Restart/Status)
- Automatic Backups (MANDATORY)
- Configuration Validation
- Safe Write Operations
- Rollback Support

Documentation:
- README.md - Getting started
- PLAN.md - Implementation details
- IMPLEMENTATION_NOTES.md - Current status
- docs/ - Full documentation

For support and bug reports, please visit the project
repository on GitHub."
}

show_quick_help() {
    show_msgbox "Quick Help" \
"Navigation:
- Use arrow keys to navigate menus
- Press Enter to select
- Press ESC to go back

Common Operations:
1. Add Frontend: Main Menu → Manage Frontends → Add
2. Add Backend: Main Menu → Manage Backends → Add
3. Add Server: Edit Backend → Manage Servers → Add
4. Reload HAProxy: Service Control → Validate & Reload
5. Create Backup: Backup & Restore → Create Manual Backup

Tips:
- All changes create automatic backups
- Always validate before reloading HAProxy
- Use 'View Details' to see current configuration
- Backups can be restored from Backup & Restore menu

For detailed help, see the documentation in docs/ directory."
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Exit and Cleanup
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

exit_application() {
    if show_yesno "Exit" "Are you sure you want to exit HAProxy CLI GUI?"; then
        clear
        echo "Thank you for using HAProxy CLI GUI!"
        log_info "HAProxy CLI GUI exiting"
        exit 0
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Entry Point
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    # Setup traps for cleanup
    setup_traps

    # Initialize application
    init_application

    # Show main menu
    show_main_menu
}

# Run main function
main "$@"
