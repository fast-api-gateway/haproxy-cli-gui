#!/bin/bash
# Module: backup-manager.sh
# Purpose: Manage HAProxy configuration backups
# CRITICAL: This module implements MANDATORY backup functionality
#           Every configuration change MUST create a full backup

# Global variables
BACKUP_DIR="${BACKUP_DIR:-./backups}"
BACKUP_RETENTION="${BACKUP_RETENTION:-50}"  # Keep last N backups
BACKUP_COMPRESS_DAYS="${BACKUP_COMPRESS_DAYS:-30}"  # Compress backups older than N days

# Initialize backup directory
init_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR" 2>/dev/null || {
            log_error "Failed to create backup directory: $BACKUP_DIR"
            return 1
        }
    fi

    # Ensure write permissions
    if [[ ! -w "$BACKUP_DIR" ]]; then
        log_error "Backup directory not writable: $BACKUP_DIR"
        return 1
    fi

    return 0
}

# Create a full backup of configuration file
# Args: $1 = source config file path
#       $2 = reason for backup (optional)
# Returns: 0 on success, 1 on failure
# Outputs: backup file path on success
create_backup() {
    local config_file="$1"
    local reason="${2:-Manual backup}"
    local timestamp
    local backup_file
    local config_basename

    # Validate input
    if [[ -z "$config_file" ]]; then
        log_error "create_backup: No config file specified"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        log_error "create_backup: Config file does not exist: $config_file"
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        log_error "create_backup: Config file not readable: $config_file"
        return 1
    fi

    # Initialize backup directory
    init_backup_dir || return 1

    # Generate timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    # Get config file basename
    config_basename=$(basename "$config_file")

    # Generate backup filename
    backup_file="${BACKUP_DIR}/${config_basename}.backup.${timestamp}"

    # Create backup with metadata header
    {
        echo "# HAProxy Configuration Backup"
        echo "# Created: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "# Original: $config_file"
        echo "# User: ${SUDO_USER:-${USER:-unknown}}"
        echo "# Reason: $reason"
        echo "# Hostname: $(hostname)"
        echo "#"
        echo ""
        cat "$config_file"
    } > "$backup_file" 2>/dev/null

    # Verify backup was created
    if [[ ! -f "$backup_file" ]]; then
        log_error "create_backup: Failed to create backup file"
        return 1
    fi

    # Verify backup content matches original (excluding metadata header)
    local backup_content_lines
    local original_content_lines
    backup_content_lines=$(tail -n +9 "$backup_file" | wc -l)
    original_content_lines=$(wc -l < "$config_file")

    if [[ $backup_content_lines -ne $original_content_lines ]]; then
        log_warn "create_backup: Backup content verification warning (lines may differ)"
    fi

    # Set appropriate permissions (match original file)
    if [[ -f "$config_file" ]]; then
        chmod --reference="$config_file" "$backup_file" 2>/dev/null || \
        chmod 600 "$backup_file" 2>/dev/null
    fi

    log_info "Backup created: $backup_file"

    # Cleanup old backups
    cleanup_old_backups

    # Output backup file path
    echo "$backup_file"
    return 0
}

# List all available backups
# Args: $1 = config file pattern (optional, default: haproxy.cfg)
# Returns: 0 on success
list_backups() {
    local pattern="${1:-haproxy.cfg}"
    local backup_files

    init_backup_dir || return 1

    # Find backup files matching pattern
    backup_files=$(find "$BACKUP_DIR" -name "${pattern}.backup.*" -type f 2>/dev/null | sort -r)

    if [[ -z "$backup_files" ]]; then
        echo "No backups found for pattern: $pattern"
        return 0
    fi

    # Display backup list with metadata
    echo "Available backups:"
    echo "=================="

    while IFS= read -r backup_file; do
        if [[ -f "$backup_file" ]]; then
            local created_date
            local reason
            local size

            # Extract metadata from backup file
            created_date=$(grep "^# Created:" "$backup_file" 2>/dev/null | cut -d: -f2- | xargs)
            reason=$(grep "^# Reason:" "$backup_file" 2>/dev/null | cut -d: -f2- | xargs)
            size=$(du -h "$backup_file" 2>/dev/null | cut -f1)

            echo ""
            echo "File: $(basename "$backup_file")"
            echo "  Created: ${created_date:-Unknown}"
            echo "  Reason:  ${reason:-Unknown}"
            echo "  Size:    ${size:-Unknown}"
        fi
    done <<< "$backup_files"

    return 0
}

# Restore configuration from backup
# Args: $1 = backup file path
#       $2 = target config file path
# Returns: 0 on success, 1 on failure
restore_backup() {
    local backup_file="$1"
    local target_file="$2"

    # Validate input
    if [[ -z "$backup_file" ]]; then
        log_error "restore_backup: No backup file specified"
        return 1
    fi

    if [[ -z "$target_file" ]]; then
        log_error "restore_backup: No target file specified"
        return 1
    fi

    if [[ ! -f "$backup_file" ]]; then
        log_error "restore_backup: Backup file does not exist: $backup_file"
        return 1
    fi

    # Create backup of current file before restoring (backup inception!)
    if [[ -f "$target_file" ]]; then
        log_info "Creating safety backup before restore..."
        create_backup "$target_file" "Before restore from $(basename "$backup_file")" > /dev/null || {
            log_error "Failed to create safety backup"
            return 1
        }
    fi

    # Extract original content (skip metadata header)
    tail -n +9 "$backup_file" > "${target_file}.tmp" 2>/dev/null || {
        log_error "Failed to extract backup content"
        rm -f "${target_file}.tmp" 2>/dev/null
        return 1
    }

    # Atomic move
    mv -f "${target_file}.tmp" "$target_file" 2>/dev/null || {
        log_error "Failed to restore backup file"
        rm -f "${target_file}.tmp" 2>/dev/null
        return 1
    }

    log_info "Configuration restored from: $(basename "$backup_file")"
    return 0
}

# Delete a specific backup
# Args: $1 = backup file path
# Returns: 0 on success, 1 on failure
delete_backup() {
    local backup_file="$1"

    if [[ -z "$backup_file" ]]; then
        log_error "delete_backup: No backup file specified"
        return 1
    fi

    if [[ ! -f "$backup_file" ]]; then
        log_error "delete_backup: Backup file does not exist: $backup_file"
        return 1
    fi

    # Safety check: only delete files in backup directory
    local backup_dir_real
    local backup_file_real
    backup_dir_real=$(realpath "$BACKUP_DIR" 2>/dev/null || echo "$BACKUP_DIR")
    backup_file_real=$(realpath "$backup_file" 2>/dev/null || echo "$backup_file")

    if [[ "$backup_file_real" != "$backup_dir_real"* ]]; then
        log_error "delete_backup: File not in backup directory"
        return 1
    fi

    rm -f "$backup_file" 2>/dev/null || {
        log_error "Failed to delete backup: $backup_file"
        return 1
    }

    log_info "Backup deleted: $(basename "$backup_file")"
    return 0
}

# Cleanup old backups based on retention policy
# Returns: 0 on success
cleanup_old_backups() {
    local backup_count
    local backups_to_delete

    init_backup_dir || return 1

    # Count existing backups
    backup_count=$(find "$BACKUP_DIR" -name "*.backup.*" -type f 2>/dev/null | wc -l)

    if [[ $backup_count -le $BACKUP_RETENTION ]]; then
        return 0  # Nothing to clean up
    fi

    # Delete oldest backups exceeding retention
    backups_to_delete=$((backup_count - BACKUP_RETENTION))

    find "$BACKUP_DIR" -name "*.backup.*" -type f 2>/dev/null | \
        sort | \
        head -n "$backups_to_delete" | \
        while IFS= read -r old_backup; do
            rm -f "$old_backup" 2>/dev/null
            log_info "Cleaned up old backup: $(basename "$old_backup")"
        done

    return 0
}

# Compare two configuration files
# Args: $1 = first config file
#       $2 = second config file
# Returns: 0 on success
compare_configs() {
    local file1="$1"
    local file2="$2"

    if [[ ! -f "$file1" ]]; then
        log_error "compare_configs: First file does not exist: $file1"
        return 1
    fi

    if [[ ! -f "$file2" ]]; then
        log_error "compare_configs: Second file does not exist: $file2"
        return 1
    fi

    # Use colordiff if available, otherwise regular diff
    if command -v colordiff &>/dev/null; then
        diff -u "$file1" "$file2" | colordiff
    else
        diff -u "$file1" "$file2"
    fi

    return 0
}

# Get backup file metadata
# Args: $1 = backup file path
# Returns: 0 on success, outputs metadata as key=value pairs
get_backup_info() {
    local backup_file="$1"

    if [[ ! -f "$backup_file" ]]; then
        log_error "get_backup_info: Backup file does not exist: $backup_file"
        return 1
    fi

    # Extract and output metadata
    echo "FILENAME=$(basename "$backup_file")"
    echo "FILEPATH=$backup_file"
    grep "^# Created:" "$backup_file" 2>/dev/null | sed 's/^# //' || echo "Created=Unknown"
    grep "^# Original:" "$backup_file" 2>/dev/null | sed 's/^# //' || echo "Original=Unknown"
    grep "^# User:" "$backup_file" 2>/dev/null | sed 's/^# //' || echo "User=Unknown"
    grep "^# Reason:" "$backup_file" 2>/dev/null | sed 's/^# //' || echo "Reason=Unknown"
    grep "^# Hostname:" "$backup_file" 2>/dev/null | sed 's/^# //' || echo "Hostname=Unknown"
    echo "SIZE=$(du -h "$backup_file" 2>/dev/null | cut -f1)"

    return 0
}

# Compress old backups to save space
# Args: $1 = days threshold (optional, default: BACKUP_COMPRESS_DAYS)
# Returns: 0 on success
compress_old_backups() {
    local days_threshold="${1:-$BACKUP_COMPRESS_DAYS}"

    init_backup_dir || return 1

    # Find uncompressed backups older than threshold
    find "$BACKUP_DIR" -name "*.backup.*" -type f ! -name "*.gz" -mtime "+${days_threshold}" 2>/dev/null | \
        while IFS= read -r old_backup; do
            gzip "$old_backup" 2>/dev/null && \
                log_info "Compressed old backup: $(basename "$old_backup")"
        done

    return 0
}

# Export backup to external location
# Args: $1 = backup file path
#       $2 = destination path
# Returns: 0 on success, 1 on failure
export_backup() {
    local backup_file="$1"
    local destination="$2"

    if [[ -z "$backup_file" ]] || [[ -z "$destination" ]]; then
        log_error "export_backup: Missing arguments"
        return 1
    fi

    if [[ ! -f "$backup_file" ]]; then
        log_error "export_backup: Backup file does not exist: $backup_file"
        return 1
    fi

    cp -p "$backup_file" "$destination" 2>/dev/null || {
        log_error "Failed to export backup to: $destination"
        return 1
    }

    log_info "Backup exported to: $destination"
    return 0
}

# MANDATORY: Pre-write backup hook
# This function MUST be called before any configuration write
# Args: $1 = config file to backup
#       $2 = reason for change
# Returns: 0 on success (backup created), 1 on failure (ABORT WRITE)
mandatory_backup_before_write() {
    local config_file="$1"
    local reason="${2:-Configuration update}"
    local backup_file

    log_info "MANDATORY BACKUP: Creating backup before write operation..."

    # Attempt to create backup
    backup_file=$(create_backup "$config_file" "$reason")
    local result=$?

    if [[ $result -ne 0 ]] || [[ -z "$backup_file" ]]; then
        log_error "CRITICAL: Mandatory backup FAILED - Write operation ABORTED"
        log_error "Configuration will NOT be modified for safety"
        return 1
    fi

    log_info "Mandatory backup completed: $(basename "$backup_file")"

    # Store backup reference for potential rollback
    export LAST_BACKUP_FILE="$backup_file"

    return 0
}

# Export functions
export -f init_backup_dir
export -f create_backup
export -f list_backups
export -f restore_backup
export -f delete_backup
export -f cleanup_old_backups
export -f compare_configs
export -f get_backup_info
export -f compress_old_backups
export -f export_backup
export -f mandatory_backup_before_write

log_debug "Backup manager module loaded"
