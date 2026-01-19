# HAProxy Bash CLI GUI - Implementation Plan

## Project Overview
A fully interactive bash-based GUI application for managing HAProxy configuration files. The application will provide an intuitive text-based interface using `dialog` or `whiptail` for configuration management, covering 60%+ of HAProxy's main features.

## Critical Requirements

### MANDATORY: Automatic Full Backup on Every Modification
**This is a non-negotiable requirement for the application:**

1. **Every configuration update MUST generate a full backup file**
2. Backup must be created BEFORE any write operation to the config file
3. Backups are timestamped: `haproxy.cfg.backup.YYYYMMDD_HHMMSS`
4. Backup creation is automatic and non-optional
5. If backup creation fails, the write operation MUST be aborted
6. All backups include metadata (timestamp, user, reason for change)
7. Backup functionality is implemented in the config writer layer

This ensures:
- Zero data loss scenarios
- Easy rollback on any error
- Full audit trail of all changes
- Protection against configuration mistakes
- Safe experimentation with settings

## Core Features Coverage (60%+ of HAProxy)

### 1. Global Configuration (10%)
- Process management (daemon, nbproc, nbthread)
- User/Group settings
- Maximum connections (maxconn)
- SSL engine configuration
- CA base directory
- Chroot settings
- Logging configuration (global level)
- Stats socket configuration
- Performance tuning parameters

### 2. Defaults Section (10%)
- Default mode (http, tcp, health)
- Timeout configurations (client, server, connect, check, http-request, http-keep-alive)
- Retry settings (retries)
- Default options (httplog, dontlognull, etc.)
- Error file definitions
- Balance algorithm defaults
- HTTP options (http-server-close, forwardfor, etc.)

### 3. Frontend Configuration (15%)
- Bind directives (IP:Port, SSL certificates)
- ACL definitions
- Use_backend rules with ACL conditions
- Default_backend specification
- HTTP request/response modifications
- Rate limiting
- Stick tables
- Compression settings
- Logging overrides
- Monitor-uri for health checks

### 4. Backend Configuration (15%)
- Balance algorithms (roundrobin, leastconn, source, uri, etc.)
- Server definitions with parameters:
  - Address and port
  - Weight
  - maxconn
  - Health check settings (check, inter, rise, fall)
  - Backup servers
  - SSL options
  - Cookie persistence
- Health check configuration (httpchk, smtpchk, mysql-check, etc.)
- HTTP options and headers
- Stick table and persistence
- Compression
- Error handling

### 5. Listen Sections (5%)
- Combined frontend/backend configuration
- Bind and server definitions
- Stats interface configuration

### 6. ACL Management (10%)
- Path-based routing
- Host-based routing
- HTTP method matching
- Header matching
- IP/Network matching
- Custom ACL expressions
- ACL combinations (AND, OR, NOT)

### 7. SSL/TLS Configuration (8%)
- Certificate management
- SSL bind options (ciphers, protocols, curves)
- SNI configuration
- Client certificate authentication
- SSL backend connections

### 8. Statistics Interface (7%)
- Stats URI configuration
- Authentication
- Refresh intervals
- Admin level access
- Hide version
- Realm configuration

### 9. Logging Configuration (5%)
- Log format customization
- Log targets (syslog servers)
- Log level settings
- HTTP log format
- TCP log format

### 10. Additional Features (10%)
- HTTP compression
- Rate limiting and DDoS protection
- HTTP/2 support
- Connection limits
- Stick tables for session persistence
- Error pages customization
- TCP mode configuration
- Health check endpoints

**Total Coverage: ~95% of main features**

## Application Architecture

### Directory Structure
```
haproxy-cli-gui/
├── haproxy-gui.sh              # Main entry point
├── lib/
│   ├── config-parser.sh        # Parse HAProxy config files
│   ├── config-writer.sh        # Write/serialize config files
│   ├── validator.sh            # Validate configuration syntax
│   ├── backup-manager.sh       # Backup/restore functionality
│   ├── utils.sh                # Common utilities and helpers
│   └── dialog-helpers.sh       # Dialog/Whiptail wrapper functions
├── modules/
│   ├── global-settings.sh      # Global section management
│   ├── defaults.sh             # Defaults section management
│   ├── frontend.sh             # Frontend management
│   ├── backend.sh              # Backend management
│   ├── listen.sh               # Listen section management
│   ├── acl.sh                  # ACL management
│   ├── ssl.sh                  # SSL/TLS configuration
│   ├── stats.sh                # Statistics interface
│   ├── logging.sh              # Logging configuration
│   └── service-control.sh      # HAProxy service management
├── templates/
│   ├── haproxy-basic.cfg       # Basic template
│   ├── haproxy-http.cfg        # HTTP load balancer template
│   ├── haproxy-ssl.cfg         # SSL termination template
│   └── haproxy-advanced.cfg    # Advanced features template
├── backups/                    # Configuration backups directory
├── tests/
│   ├── test-parser.sh          # Unit tests for parser
│   ├── test-writer.sh          # Unit tests for writer
│   └── test-modules.sh         # Integration tests
├── docs/
│   ├── FEATURES.md             # Detailed feature documentation
│   ├── USAGE.md                # User guide
│   └── API.md                  # Internal API documentation
├── README.md                   # Project README
├── PLAN.md                     # This file
└── LICENSE                     # License file
```

### Module Descriptions

#### 1. Main Entry Point (haproxy-gui.sh)
- Initialize application
- Load all libraries and modules
- Display main menu
- Handle user navigation
- Manage application state
- Exit and cleanup

#### 2. Config Parser (lib/config-parser.sh)
Functions:
- `parse_config()` - Parse entire config file into memory structure
- `get_section()` - Extract specific section (global, defaults, frontend, backend, listen)
- `get_section_names()` - List all sections of a type
- `get_directive()` - Get specific directive value
- `section_exists()` - Check if section exists
- `validate_syntax()` - Basic syntax validation

Data structure: Associative arrays indexed by section:directive

#### 3. Config Writer (lib/config-writer.sh)
Functions:
- `write_config()` - Write memory structure to file
- `add_section()` - Add new section
- `update_section()` - Modify existing section
- `delete_section()` - Remove section
- `add_directive()` - Add directive to section
- `update_directive()` - Modify directive
- `delete_directive()` - Remove directive
- `format_config()` - Pretty print configuration

#### 4. Validator (lib/validator.sh)
Functions:
- `validate_config_file()` - Run haproxy -c -f check
- `validate_section_syntax()` - Check section syntax
- `validate_bind_address()` - Validate IP:Port format
- `validate_server_line()` - Validate server definition
- `validate_acl_syntax()` - Validate ACL expressions
- `validate_timeout()` - Validate timeout values
- `check_conflicts()` - Check for configuration conflicts

#### 5. Backup Manager (lib/backup-manager.sh)
Functions:
- `create_backup()` - Create timestamped backup
- `list_backups()` - Show available backups
- `restore_backup()` - Restore from backup
- `delete_backup()` - Remove backup
- `auto_backup()` - Automatic backup before changes
- `compare_configs()` - Show diff between configs

#### 6. Utilities (lib/utils.sh)
Functions:
- `log_message()` - Logging function
- `show_error()` - Display error messages
- `show_success()` - Display success messages
- `confirm_action()` - Confirmation dialog
- `show_info()` - Information display
- `trim_string()` - String manipulation
- `is_valid_ip()` - IP address validation
- `is_valid_port()` - Port validation

#### 7. Dialog Helpers (lib/dialog-helpers.sh)
Functions:
- `dialog_menu()` - Display menu
- `dialog_input()` - Text input dialog
- `dialog_yesno()` - Yes/No confirmation
- `dialog_msgbox()` - Message box
- `dialog_checklist()` - Multiple selection
- `dialog_radiolist()` - Single selection
- `dialog_form()` - Form with multiple fields
- `dialog_gauge()` - Progress indicator

### Menu Structure

```
Main Menu
├── 1. View Current Configuration
│   ├── Display full config
│   ├── Display by section
│   └── Export to file
│
├── 2. Global Settings
│   ├── View global settings
│   ├── Edit max connections
│   ├── Edit user/group
│   ├── Configure logging
│   ├── Configure stats socket
│   └── Advanced settings
│
├── 3. Defaults Section
│   ├── View defaults
│   ├── Edit mode
│   ├── Configure timeouts
│   ├── Edit retry settings
│   ├── Configure options
│   └── HTTP defaults
│
├── 4. Frontend Management
│   ├── List frontends
│   ├── Add new frontend
│   ├── Edit frontend
│   │   ├── Edit bind addresses
│   │   ├── Manage ACLs
│   │   ├── Configure backend routing
│   │   ├── Set default backend
│   │   ├── HTTP settings
│   │   ├── SSL settings
│   │   └── Advanced options
│   ├── Delete frontend
│   └── Clone frontend
│
├── 5. Backend Management
│   ├── List backends
│   ├── Add new backend
│   ├── Edit backend
│   │   ├── Edit balance algorithm
│   │   ├── Manage servers
│   │   │   ├── Add server
│   │   │   ├── Edit server
│   │   │   ├── Delete server
│   │   │   └── Configure health checks
│   │   ├── Configure persistence
│   │   ├── HTTP options
│   │   ├── SSL backend settings
│   │   └── Advanced options
│   ├── Delete backend
│   └── Clone backend
│
├── 6. Listen Sections
│   ├── List listen sections
│   ├── Add new listen
│   ├── Edit listen
│   ├── Delete listen
│   └── Configure stats interface
│
├── 7. ACL Management
│   ├── List all ACLs
│   ├── Add ACL
│   ├── Edit ACL
│   ├── Delete ACL
│   ├── Test ACL expression
│   └── ACL templates (common patterns)
│
├── 8. SSL/TLS Configuration
│   ├── List SSL certificates
│   ├── Configure SSL bind options
│   ├── Configure SSL ciphers
│   ├── SNI configuration
│   └── Backend SSL settings
│
├── 9. Statistics Interface
│   ├── Enable/disable stats
│   ├── Configure stats URI
│   ├── Set authentication
│   ├── Configure options
│   └── View live stats (if enabled)
│
├── 10. Logging Configuration
│   ├── Configure log targets
│   ├── Set log format
│   ├── Configure log level
│   └── Custom log format
│
├── 11. Advanced Features
│   ├── Rate limiting
│   ├── Compression
│   ├── Stick tables
│   ├── Error pages
│   ├── HTTP/2 settings
│   └── Connection limits
│
├── 12. Templates
│   ├── Load basic template
│   ├── Load HTTP LB template
│   ├── Load SSL termination template
│   ├── Load advanced template
│   └── Save current as template
│
├── 13. Validation & Testing
│   ├── Validate current config
│   ├── Test configuration
│   ├── Check syntax
│   └── View validation report
│
├── 14. Backup & Restore
│   ├── Create backup
│   ├── List backups
│   ├── Restore from backup
│   ├── Delete backup
│   └── Compare configs
│
├── 15. Service Control
│   ├── Check HAProxy status
│   ├── Reload configuration
│   ├── Restart HAProxy
│   ├── Stop HAProxy
│   └── View logs
│
├── 16. Configuration File
│   ├── Change config file path
│   ├── Import configuration
│   ├── Export configuration
│   └── Reset to default
│
├── 17. Help & About
│   ├── Quick start guide
│   ├── Feature documentation
│   ├── Keyboard shortcuts
│   └── About
│
└── 18. Exit
    ├── Save and exit
    ├── Exit without saving
    └── Cancel
```

## User Interface Design

### Dialog/Whiptail Features
- Color-coded menus (green for success, red for errors, yellow for warnings)
- Progress bars for long operations
- Form-based input for complex configurations
- Checkbox lists for multi-select options
- Radio lists for single-select options
- Confirmation dialogs for destructive operations
- Help text in all dialogs

### Display Features
- Syntax highlighting for config display
- Section headers with clear formatting
- Line numbers for easy reference
- Current values displayed in edit dialogs
- Validation feedback in real-time
- Status indicators (enabled/disabled, active/inactive)

## Key Implementation Details

### 1. Configuration Parsing Strategy
- Read config file line by line
- Track current section context
- Store in associative arrays: `CONFIG[section_name:directive]=value`
- Handle multi-line directives
- Preserve comments for rewriting
- Track indentation for proper formatting

### 2. Safe Configuration Writing
- **MANDATORY: Always create full backup before ANY modification** - This is a critical requirement
- Every config update MUST generate a timestamped full backup file
- Backup creation is non-optional and happens automatically before writes
- Validate before writing
- Use atomic file operations (write to temp, then mv)
- Preserve file permissions
- Log all changes with backup reference
- Rollback capability on errors using backup files

### 3. HAProxy Integration
- Use `haproxy -c -f config` for validation
- Use `systemctl` or `service` for control
- Read from standard paths (/etc/haproxy/haproxy.cfg)
- Support custom config file paths
- Socket communication for runtime stats

### 4. Error Handling
- Comprehensive input validation
- Graceful error messages
- Automatic rollback on failures
- Error logging
- User-friendly error descriptions
- Recovery suggestions

### 5. Performance Considerations
- Lazy loading of sections
- Cache parsed configuration
- Efficient array operations
- Minimal external command calls
- Batch operations where possible

## Security Considerations

1. **File Permissions**
   - Check write permissions before modifications
   - Maintain original file ownership
   - Secure backup storage
   - No hardcoded credentials

2. **Input Validation**
   - Sanitize all user inputs
   - Prevent command injection
   - Validate file paths
   - Check for path traversal

3. **Privilege Management**
   - Check for root/sudo when needed
   - Clear privilege requirement messages
   - Minimal privilege principle

## Testing Strategy

### Unit Tests
- Test each parser function
- Test each writer function
- Test validation functions
- Test utility functions

### Integration Tests
- Test complete workflows (add/edit/delete)
- Test backup/restore
- Test config file handling
- Test HAProxy integration

### Test Cases
1. Parse valid HAProxy config
2. Parse malformed config (error handling)
3. Add new frontend
4. Edit existing backend
5. Delete section
6. Backup and restore
7. Validate configuration
8. Service reload
9. Handle large configs (1000+ lines)
10. Handle concurrent edits

## Documentation Requirements

### README.md
- Project description
- Features overview
- Installation instructions
- Quick start guide
- Screenshots/demo
- Requirements
- License

### USAGE.md
- Detailed user guide
- Step-by-step tutorials
- Common workflows
- Tips and tricks
- Troubleshooting

### FEATURES.md
- Complete feature list
- HAProxy feature mapping
- Examples for each feature
- Limitations

### API.md (Internal)
- Function reference
- Module interfaces
- Data structures
- Contribution guidelines

## Dependencies

### Required
- bash (4.0+)
- dialog or whiptail
- haproxy
- Basic utilities: sed, awk, grep, cat, diff

### Optional
- systemctl (for service management)
- git (for version control)
- colordiff (for better diff display)

## Development Phases

### Phase 1: Core Infrastructure (Foundation)
- Setup project structure
- Create main entry point
- Implement config parser
- Implement config writer
- Basic menu system
- Utility functions

### Phase 2: Essential Modules
- Global settings module
- Defaults module
- Frontend module (basic)
- Backend module (basic)
- Validation module

### Phase 3: Advanced Features
- ACL management
- SSL/TLS configuration
- Complete frontend features
- Complete backend features
- Listen sections

### Phase 4: Support Features
- Backup/restore
- Service control
- Logging configuration
- Stats interface

### Phase 5: Enhancement
- Templates
- Advanced features (compression, rate limiting, etc.)
- Testing suite
- Documentation

### Phase 6: Polish
- Error handling improvements
- Performance optimization
- User experience refinements
- Final testing

## Success Criteria

1. ✅ Parse and display existing HAProxy configurations correctly
2. ✅ Add new frontends, backends, and listen sections
3. ✅ Edit existing configurations without breaking syntax
4. ✅ Delete sections safely with confirmation
5. ✅ Validate configurations before applying
6. ✅ **Create full backup automatically before EVERY config modification (MANDATORY)**
7. ✅ Reload HAProxy service after changes
8. ✅ Cover 60%+ of HAProxy features
9. ✅ Intuitive and user-friendly interface
10. ✅ Comprehensive error handling
11. ✅ Complete documentation
12. ✅ Passing test suite

## Future Enhancements (Post-MVP)

1. Configuration version control integration
2. Multi-file configuration support
3. Configuration templates marketplace
4. Real-time HAProxy statistics dashboard
5. Log analysis tools
6. Performance recommendations
7. Security audit features
8. Configuration migration tools
9. API for automation
10. Web-based version

## Estimated Complexity

- **Lines of Code**: ~3000-4000 (bash)
- **Functions**: ~150-200
- **Modules**: 10-12
- **Test Cases**: 50+
- **Documentation Pages**: 4-5

## Risk Mitigation

1. **Risk**: Breaking production HAProxy config
   - **Mitigation**: Mandatory backups, validation before apply, dry-run mode

2. **Risk**: Complex ACL syntax parsing
   - **Mitigation**: Template-based approach, validation helper, examples

3. **Risk**: User errors in configuration
   - **Mitigation**: Input validation, confirmation dialogs, clear documentation

4. **Risk**: Performance with large configs
   - **Mitigation**: Efficient parsing, caching, lazy loading

5. **Risk**: Compatibility across HAProxy versions
   - **Mitigation**: Version detection, feature compatibility checks

## Conclusion

This plan provides a comprehensive roadmap for building a fully-featured bash CLI GUI for HAProxy configuration management. The modular architecture allows for incremental development and testing, while the extensive feature coverage ensures the application meets professional standards. The focus on usability, safety, and comprehensive error handling will make this tool valuable for both beginners and experienced HAProxy administrators.
