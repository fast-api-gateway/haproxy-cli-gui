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
            "7" "Backup & Restore" \
            "8" "Configuration File" \
            "9" "Help & About" \
            "0" "Exit")

        case "$choice" in
            1) menu_view_config ;;
            2) menu_frontends ;;
            3) menu_backends ;;
            4) menu_global_settings ;;
            5) menu_defaults_settings ;;
            6) menu_validation ;;
            7) menu_backup_restore ;;
            8) menu_config_file ;;
            9) menu_help ;;
            0|"") exit_application ;;
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
            "3" "Delete Frontend" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) list_frontends ;;
            2) add_frontend ;;
            3) delete_frontend ;;
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
            "3" "Delete Backend" \
            "0" "Back to Main Menu")

        case "$choice" in
            1) list_backends ;;
            2) add_backend ;;
            3) delete_backend ;;
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

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Settings Menus (Placeholder)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_global_settings() {
    show_msgbox "Global Settings" "Global settings management\n(Coming in next phase)"
}

menu_defaults_settings() {
    show_msgbox "Defaults Settings" "Defaults settings management\n(Coming in next phase)"
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
# Help Menu
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

menu_help() {
    show_msgbox "HAProxy CLI GUI - About" \
"HAProxy CLI GUI v1.0.0

A fully interactive bash-based terminal GUI for managing
HAProxy configuration files.

CRITICAL FEATURE:
Every configuration modification automatically creates a
full backup file before making changes.

Features:
- Frontend & Backend Management
- Automatic Backups (MANDATORY)
- Configuration Validation
- Safe Write Operations
- Rollback Support

Documentation:
- README.md - Getting started
- PLAN.md - Implementation details
- docs/ - Full documentation

For support and bug reports, please visit the project
repository on GitHub."
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
