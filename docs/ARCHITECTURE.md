# HAProxy CLI GUI - Architecture Documentation

## System Overview

The HAProxy CLI GUI is built as a modular bash application with clear separation of concerns. The architecture follows a layered approach with core libraries, feature modules, and a centralized main controller.

## Architectural Layers

```
┌─────────────────────────────────────────────────────────┐
│                   User Interface Layer                   │
│              (Dialog/Whiptail based TUI)                 │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                   Main Controller                        │
│                  (haproxy-gui.sh)                        │
│  - Menu navigation                                       │
│  - State management                                      │
│  - Module orchestration                                  │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                  Feature Modules Layer                   │
├──────────────┬──────────────┬───────────────────────────┤
│  Global      │  Defaults    │  Frontend                 │
│  Backend     │  Listen      │  ACL                      │
│  SSL         │  Stats       │  Logging                  │
│  Service     │              │                           │
└──────────────┴──────────────┴───────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                   Core Libraries Layer                   │
├──────────────┬──────────────┬───────────────────────────┤
│ Config       │ Config       │  Validator                │
│ Parser       │ Writer       │                           │
├──────────────┼──────────────┼───────────────────────────┤
│ Backup       │ Utils        │  Dialog                   │
│ Manager      │              │  Helpers                  │
└──────────────┴──────────────┴───────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                 External Dependencies                    │
│  HAProxy | Dialog/Whiptail | SystemD | Bash Utils      │
└─────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Main Controller (haproxy-gui.sh)

**Responsibilities:**
- Application initialization and bootstrap
- Main menu display and navigation
- Module loading and coordination
- State management
- Error handling and recovery
- Clean shutdown

**Key Functions:**
```bash
main()                    # Entry point
init_application()        # Initialize app, load modules
show_main_menu()         # Display main menu
load_modules()           # Source all module files
cleanup()                # Clean up on exit
handle_error()           # Global error handler
```

**State Variables:**
```bash
CURRENT_CONFIG_FILE      # Active config file path
CONFIG_MODIFIED          # Flag for unsaved changes
CURRENT_SECTION          # Active section being edited
BACKUP_ENABLED           # Auto-backup flag
VALIDATION_MODE          # Strict/permissive validation
```

### 2. Configuration Parser (lib/config-parser.sh)

**Purpose:** Parse HAProxy configuration files into memory structures for manipulation.

**Data Structure:**
Uses bash associative arrays to store configuration:
```bash
declare -A CONFIG           # Main config storage
declare -A CONFIG_ORDER     # Preserve section order
declare -A CONFIG_COMMENTS  # Store inline comments

# Example structure:
CONFIG["global:maxconn"]="4096"
CONFIG["defaults:timeout_connect"]="5000ms"
CONFIG["frontend:http_front:bind"]="*:80"
CONFIG["backend:web_servers:balance"]="roundrobin"
CONFIG["backend:web_servers:server:web1"]="192.168.1.10:8080 check"
```

**Key Functions:**
```bash
parse_config_file()           # Main parser entry point
parse_section()               # Parse specific section type
get_section_list()            # Get all sections of type
get_directive_value()         # Get specific directive
section_exists()              # Check section existence
get_servers_in_backend()      # Get all servers in backend
get_acls_in_frontend()        # Get all ACLs in frontend
extract_section_lines()       # Get raw lines for section
```

**Parsing Algorithm:**
1. Read file line by line
2. Track current section context
3. Parse directives and values
4. Handle multi-line directives
5. Preserve comments and formatting
6. Build indexed data structure

### 3. Configuration Writer (lib/config-writer.sh)

**Purpose:** Serialize memory structures back to HAProxy configuration format.

**Key Functions:**
```bash
write_config_file()           # Write complete config
add_section()                 # Add new section
update_section()              # Modify existing section
delete_section()              # Remove section
add_directive()               # Add directive to section
update_directive()            # Modify directive value
delete_directive()            # Remove directive
format_section()              # Format section with indentation
preserve_comments()           # Maintain comment blocks
```

**Writing Strategy:**
1. Create temporary file
2. Write sections in order (global, defaults, frontends, backends, listen)
3. Apply proper indentation
4. Preserve comments
5. Validate output
6. Atomic replace (mv temp to target)

**Safety Measures:**
- Always backup before write
- Validate before moving temp file
- Preserve file permissions
- Lock file during write
- Rollback on error

### 4. Validator (lib/validator.sh)

**Purpose:** Validate configuration syntax and semantics.

**Validation Levels:**
1. **Syntax Level**: Basic bash parsing
2. **Semantic Level**: HAProxy rules and relationships
3. **HAProxy Level**: Native `haproxy -c -f` validation

**Key Functions:**
```bash
validate_full_config()        # Complete validation
validate_section_syntax()     # Section-specific validation
validate_bind_directive()     # Validate bind addresses
validate_server_line()        # Validate server definition
validate_acl_expression()     # Validate ACL syntax
validate_timeout_value()      # Validate timeout format
validate_ip_address()         # IP validation
validate_port_number()        # Port validation
check_section_references()    # Check backend/frontend refs
run_haproxy_check()          # Run haproxy -c -f
```

**Validation Rules:**
```bash
# Bind address format
bind_pattern="^[*0-9a-fA-F:.]+:[0-9]+( ssl)?( crt .*)?$"

# Server line format
server_pattern="^[a-zA-Z0-9_-]+ [0-9a-fA-F:.]+:[0-9]+.*$"

# ACL expression format
acl_pattern="^[a-zA-Z0-9_-]+ [a-z_]+ .*$"

# Timeout format
timeout_pattern="^[0-9]+(ms|s|m|h|d)?$"
```

### 5. Backup Manager (lib/backup-manager.sh)

**Purpose:** Manage configuration backups and restore operations.

**Backup Strategy:**
- Automatic backup before any modification
- Timestamped filenames: `haproxy.cfg.backup.YYYYMMDD_HHMMSS`
- Configurable retention (default: keep last 50 backups)
- Optional compression for old backups

**Key Functions:**
```bash
create_backup()               # Create timestamped backup
list_backups()                # Show available backups
restore_backup()              # Restore from backup
delete_backup()               # Remove specific backup
cleanup_old_backups()         # Rotate old backups
compare_configs()             # Diff two configs
get_backup_info()             # Get backup metadata
```

**Backup Metadata:**
```bash
# Stored in backup file header as comments
# Created: 2024-01-15 10:30:45
# Original: /etc/haproxy/haproxy.cfg
# Created by: admin
# Reason: Before adding frontend http_front
```

### 6. Utilities (lib/utils.sh)

**Purpose:** Common utility functions used across modules.

**Categories:**

**Logging:**
```bash
log_info()                # Info level log
log_warn()                # Warning level log
log_error()               # Error level log
log_debug()               # Debug level log
```

**Display:**
```bash
show_success()            # Success message dialog
show_error()              # Error message dialog
show_warning()            # Warning message dialog
show_info()               # Info message dialog
```

**Validation:**
```bash
is_valid_ip()             # Validate IP address
is_valid_port()           # Validate port number
is_valid_timeout()        # Validate timeout format
is_valid_name()           # Validate section names
```

**String Operations:**
```bash
trim()                    # Trim whitespace
to_lower()                # Convert to lowercase
to_upper()                # Convert to uppercase
escape_string()           # Escape special chars
```

**File Operations:**
```bash
ensure_directory()        # Create dir if not exists
safe_write()              # Write with temp+mv
get_file_hash()           # Calculate file checksum
```

### 7. Dialog Helpers (lib/dialog-helpers.sh)

**Purpose:** Wrapper functions for dialog/whiptail with consistent styling.

**Key Functions:**
```bash
show_menu()               # Display menu
show_form()               # Display input form
show_yesno()              # Yes/no dialog
show_msgbox()             # Message box
show_inputbox()           # Single input
show_checklist()          # Multiple selection
show_radiolist()          # Single selection
show_textbox()            # Display text file
show_gauge()              # Progress bar
```

**Styling Constants:**
```bash
DIALOG_HEIGHT=20
DIALOG_WIDTH=70
DIALOG_TITLE="HAProxy CLI GUI"
DIALOG_BACKTITLE="HAProxy Configuration Manager"
```

## Feature Modules

### Module Architecture

Each feature module follows a consistent structure:

```bash
#!/bin/bash
# Module: module-name.sh
# Purpose: Brief description

# Dependencies
source "${LIB_DIR}/config-parser.sh"
source "${LIB_DIR}/config-writer.sh"
source "${LIB_DIR}/validator.sh"
source "${LIB_DIR}/utils.sh"

# Module-specific functions
function module_main_menu() {
    # Display module menu
}

function module_list() {
    # List items
}

function module_add() {
    # Add new item
}

function module_edit() {
    # Edit existing item
}

function module_delete() {
    # Delete item
}

# Export functions
export -f module_main_menu
export -f module_list
export -f module_add
export -f module_edit
export -f module_delete
```

### Module: Frontend (modules/frontend.sh)

**Responsibilities:**
- Manage frontend sections
- Configure bind addresses
- Manage ACLs
- Configure backend routing
- SSL configuration
- HTTP settings

**Key Functions:**
```bash
frontend_menu()
list_frontends()
add_frontend()
edit_frontend()
    edit_frontend_binds()
    edit_frontend_acls()
    edit_frontend_backends()
    edit_frontend_ssl()
delete_frontend()
clone_frontend()
```

### Module: Backend (modules/backend.sh)

**Responsibilities:**
- Manage backend sections
- Configure balance algorithms
- Manage servers
- Configure health checks
- Session persistence
- SSL backend settings

**Key Functions:**
```bash
backend_menu()
list_backends()
add_backend()
edit_backend()
    edit_balance_algorithm()
    manage_servers()
        add_server()
        edit_server()
        delete_server()
    edit_health_checks()
    edit_persistence()
delete_backend()
clone_backend()
```

## Data Flow

### Configuration Read Flow
```
User Action
    ↓
Main Menu Selection
    ↓
Module Function Called
    ↓
Load Config (if not cached)
    ↓
Parse Config File
    ↓
Populate CONFIG arrays
    ↓
Display Data in Dialog
```

### Configuration Write Flow
```
User Input in Form
    ↓
Validate Input
    ↓
Update CONFIG arrays
    ↓
Create Backup
    ↓
Serialize to Temp File
    ↓
Validate Temp File
    ↓
Atomic Replace
    ↓
Show Success Message
```

### Error Handling Flow
```
Operation Failed
    ↓
Capture Error Details
    ↓
Log Error
    ↓
Attempt Rollback (if applicable)
    ↓
Show User-Friendly Error
    ↓
Provide Recovery Options
    ↓
Return to Safe State
```

## Configuration Caching

### Cache Strategy
- Parse configuration once on startup
- Cache in memory (associative arrays)
- Mark as dirty when modified
- Reload only when file changes externally
- Periodic refresh option

### Cache Invalidation
- After external edits
- After service reload
- Manual refresh by user
- File modification time check

## Concurrency and Locking

### File Locking
```bash
# Lock file before modification
exec 200>/var/lock/haproxy-gui.lock
flock -n 200 || die "Another instance is running"

# ... perform operations ...

# Release lock
flock -u 200
```

### Multiple Instance Prevention
- Lock file in /var/lock/
- PID file tracking
- Warning if another instance detected

## Error Recovery

### Recovery Strategies

1. **Configuration Parse Error**
   - Show error details
   - Offer to restore from backup
   - Allow manual fix
   - Skip problematic section

2. **Validation Error**
   - Show validation output
   - Highlight problem area
   - Suggest fixes
   - Allow edit or rollback

3. **Write Error**
   - Automatic rollback
   - Restore from backup
   - Preserve user input
   - Retry option

4. **HAProxy Reload Error**
   - Keep old configuration active
   - Show error log
   - Allow fix and retry
   - Emergency rollback

## Performance Considerations

### Optimization Techniques

1. **Lazy Loading**: Load modules only when needed
2. **Caching**: Cache parsed configuration in memory
3. **Batch Operations**: Group multiple changes
4. **Efficient Parsing**: Use bash built-ins over external commands
5. **Minimal Subshells**: Avoid unnecessary subshells

### Performance Targets
- Startup time: < 2 seconds
- Config parse: < 1 second for 1000-line config
- Menu navigation: Instant (<100ms)
- Save operation: < 2 seconds including validation

## Security Considerations

### Input Sanitization
```bash
sanitize_input() {
    local input="$1"
    # Remove dangerous characters
    input="${input//[;&|<>]/}"
    # Trim whitespace
    input="$(trim "$input")"
    echo "$input"
}
```

### Command Injection Prevention
- Never use eval with user input
- Quote all variables
- Validate input against patterns
- Use parameter expansion over subshells

### File Security
- Check file permissions before read/write
- Maintain original ownership
- Secure backup directory
- No world-readable sensitive data

## Testing Architecture

### Test Levels

1. **Unit Tests**: Test individual functions
2. **Integration Tests**: Test module interactions
3. **System Tests**: Test complete workflows
4. **Validation Tests**: Test against real HAProxy

### Test Framework
```bash
# tests/test-framework.sh
test_suite_init()
test_case()
assert_equals()
assert_not_equals()
assert_contains()
assert_file_exists()
test_suite_cleanup()
```

## Logging

### Log Levels
- DEBUG: Detailed debugging information
- INFO: General information
- WARN: Warning messages
- ERROR: Error messages

### Log Format
```
[YYYY-MM-DD HH:MM:SS] [LEVEL] [MODULE] Message
```

### Log Location
- Default: `/var/log/haproxy-gui.log`
- Configurable via environment variable
- Optional syslog integration

## Extension Points

### Plugin Architecture (Future)
```bash
# Load plugins from plugins/ directory
load_plugins() {
    for plugin in "${PLUGIN_DIR}"/*.sh; do
        source "$plugin"
    done
}

# Plugin interface
plugin_init()
plugin_menu()
plugin_cleanup()
```

### Custom Validators
```bash
# Register custom validators
register_validator() {
    CUSTOM_VALIDATORS+=("$1")
}
```

### Custom Templates
```bash
# Register custom templates
register_template() {
    CUSTOM_TEMPLATES+=("$1")
}
```

## Deployment Considerations

### Installation
- Single directory deployment
- No compilation required
- Minimal dependencies
- Works with existing HAProxy installation

### Configuration
- Environment variables
- Config file (~/.haproxy-gui.conf)
- Command-line arguments
- Sensible defaults

### Updates
- Git pull for updates
- Preserve user data
- Backward compatible
- Migration scripts if needed

## Monitoring and Debugging

### Debug Mode
```bash
# Enable with DEBUG=1
export DEBUG=1
./haproxy-gui.sh
```

### Verbose Output
```bash
# Enable with VERBOSE=1
export VERBOSE=1
./haproxy-gui.sh
```

### Tracing
```bash
# Enable bash tracing
set -x
```

## Summary

This architecture provides:
- Clear separation of concerns
- Modular and extensible design
- Robust error handling
- Safe configuration management
- Good performance characteristics
- Security-conscious implementation
- Comprehensive testing support

The layered approach ensures that changes to one component don't affect others, making the system maintainable and extensible for future enhancements.
