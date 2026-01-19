#!/bin/bash
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# HAProxy CLI GUI - Interactive Terminal Configuration Manager
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Version: 1.0.0
# Description: Full-featured bash GUI for managing HAProxy configurations
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
            "4" "Global Settings" \
            "5" "Defaults Settings" \
            "6" "Validation & Testing" \
            "7" "Service Control" \
            "8" "Backup & Restore" \
            "9" "Configuration File" \
            "0" "Help & Exit")

        case "$choice" in
            1) menu_view_config ;;
            2) menu_frontends ;;
            3) menu_backends ;;
            4) menu_global_settings ;;
            5) menu_defaults_settings ;;
            6) menu_validation ;;
            7) menu_service_control ;;
            8) menu_backup_restore ;;
            9) menu_config_file ;;
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
            "2" "Add Server" \
            "3" "Delete Server" \
            "0" "Back")

        case "$choice" in
            1) list_servers "$backend_name" ;;
            2) add_server "$backend_name" ;;
            3) delete_server "$backend_name" ;;
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
