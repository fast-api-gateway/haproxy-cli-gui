# HAProxy CLI GUI

A fully interactive bash-based terminal GUI application for managing HAProxy configuration files with comprehensive feature coverage and user-friendly interface.

## Overview

HAProxy CLI GUI is a powerful text-based user interface (TUI) tool that simplifies HAProxy configuration management. Built entirely in bash with dialog/whiptail, it provides an intuitive way to view, create, edit, and delete HAProxy configurations without manually editing configuration files.

## Features

### Core Capabilities
- ✅ **Full Configuration Management**: List, add, edit, and delete all major HAProxy sections
- ✅ **Interactive Menus**: Easy-to-navigate dialog-based interface
- ✅ **Safe Operations**: Automatic backups before any changes
- ✅ **Validation**: Built-in syntax checking and HAProxy validation
- ✅ **Service Control**: Reload, restart, and monitor HAProxy service
- ✅ **60%+ Feature Coverage**: Comprehensive support for main HAProxy features

### Supported HAProxy Features

#### Global Configuration
- Process management (daemon, threads, processes)
- User/Group settings
- Connection limits
- SSL engine configuration
- Logging configuration
- Stats socket management

#### Defaults Section
- Mode configuration (HTTP/TCP/Health)
- Timeout settings (client, server, connect, check)
- Retry and error handling
- HTTP defaults (logging, headers, options)
- Balance algorithm defaults

#### Frontend Management
- Bind addresses and SSL configuration
- ACL definitions and routing rules
- Backend selection logic
- HTTP request/response modifications
- Rate limiting and compression
- Statistics URI

#### Backend Management
- Load balancing algorithms (roundrobin, leastconn, source, uri, etc.)
- Server management with full parameters
- Health check configuration
- Session persistence (cookies, stick tables)
- SSL backend connections
- HTTP headers and options

#### Listen Sections
- Combined frontend/backend configuration
- Statistics interface setup

#### ACL Management
- Path-based routing
- Host-based routing
- HTTP method matching
- Header and IP matching
- Custom expressions

#### SSL/TLS Configuration
- Certificate management
- Cipher and protocol configuration
- SNI support
- Client certificate authentication

#### Additional Features
- Statistics interface configuration
- Logging customization
- HTTP compression
- Rate limiting
- Connection limits
- Error page customization
- Templates for common scenarios

## Installation

### Prerequisites

Required:
- bash 4.0 or higher
- dialog or whiptail
- haproxy
- Standard Unix utilities (sed, awk, grep)

Optional:
- systemctl (for service management)
- colordiff (for better diff display)

### Install

```bash
# Clone the repository
git clone https://github.com/yourusername/haproxy-cli-gui.git
cd haproxy-cli-gui

# Make the main script executable
chmod +x haproxy-gui.sh

# Run the application
sudo ./haproxy-gui.sh
```

Note: Root privileges are typically required to read/modify HAProxy configuration and control the service.

## Quick Start

1. **Launch the application**:
   ```bash
   sudo ./haproxy-gui.sh
   ```

2. **Navigate the menus**:
   - Use arrow keys to navigate
   - Press Enter to select
   - Press ESC to go back

3. **View current configuration**:
   - Select "View Current Configuration" from main menu
   - Review all sections or drill down into specific ones

4. **Add a new frontend**:
   - Navigate to "Frontend Management"
   - Select "Add new frontend"
   - Fill in the form (name, bind address, backend)
   - Configuration is automatically validated and saved

5. **Edit a backend**:
   - Navigate to "Backend Management"
   - Select "Edit backend"
   - Choose the backend to edit
   - Modify settings or add/remove servers
   - Changes are validated before saving

6. **Reload HAProxy**:
   - Navigate to "Service Control"
   - Select "Reload configuration"
   - HAProxy will reload with new configuration

## Usage Examples

### Example 1: Create HTTP Load Balancer

1. Set up frontend:
   - Frontend Management → Add new frontend
   - Name: `http_front`
   - Bind: `*:80`
   - Mode: `http`
   - Default backend: `web_servers`

2. Set up backend:
   - Backend Management → Add new backend
   - Name: `web_servers`
   - Balance: `roundrobin`
   - Add servers:
     - `web1 192.168.1.10:8080 check`
     - `web2 192.168.1.11:8080 check`
     - `web3 192.168.1.12:8080 check`

3. Validate and reload:
   - Validation & Testing → Validate current config
   - Service Control → Reload configuration

### Example 2: SSL Termination

1. Configure frontend with SSL:
   - Frontend Management → Add new frontend
   - Name: `https_front`
   - Bind: `*:443 ssl crt /etc/haproxy/certs/`
   - Add ACLs for routing
   - Set backend rules

2. Configure SSL options:
   - SSL/TLS Configuration → Configure SSL bind options
   - Set cipher suites
   - Configure protocols (TLSv1.2, TLSv1.3)

### Example 3: Load Template

1. Load predefined template:
   - Templates → Load HTTP LB template
   - Customize settings as needed
   - Save configuration

## Project Structure

```
haproxy-cli-gui/
├── haproxy-gui.sh              # Main application entry point
├── lib/                        # Core libraries
│   ├── config-parser.sh        # Configuration parsing
│   ├── config-writer.sh        # Configuration writing
│   ├── validator.sh            # Validation functions
│   ├── backup-manager.sh       # Backup/restore
│   ├── utils.sh                # Utility functions
│   └── dialog-helpers.sh       # UI helpers
├── modules/                    # Feature modules
│   ├── global-settings.sh      # Global configuration
│   ├── defaults.sh             # Defaults section
│   ├── frontend.sh             # Frontend management
│   ├── backend.sh              # Backend management
│   ├── listen.sh               # Listen sections
│   ├── acl.sh                  # ACL management
│   ├── ssl.sh                  # SSL configuration
│   ├── stats.sh                # Statistics
│   ├── logging.sh              # Logging
│   └── service-control.sh      # Service management
├── templates/                  # Configuration templates
├── backups/                    # Configuration backups
├── tests/                      # Test suite
└── docs/                       # Documentation
```

## Configuration

### Default Configuration File
By default, the application manages `/etc/haproxy/haproxy.cfg`. You can change this in the application:
- Main Menu → Configuration File → Change config file path

### Backup Location
Backups are stored in `./backups/` by default. Each backup is timestamped for easy identification.

### Settings
Application settings can be configured by editing variables in `haproxy-gui.sh`:
```bash
CONFIG_FILE="/etc/haproxy/haproxy.cfg"
BACKUP_DIR="./backups"
AUTO_BACKUP=true
VALIDATION_BEFORE_SAVE=true
```

## Safety Features

1. **Automatic Backups**: Every change creates a timestamped backup
2. **Validation**: All configurations are validated before saving
3. **Confirmation Dialogs**: Destructive operations require confirmation
4. **Rollback**: Easy restore from any backup
5. **Dry-run Mode**: Test changes without applying them
6. **Atomic Operations**: Configuration changes are atomic (all or nothing)

## Troubleshooting

### Dialog not found
```bash
# Install dialog on Debian/Ubuntu
sudo apt-get install dialog

# Install dialog on CentOS/RHEL
sudo yum install dialog
```

### Permission denied
The application requires root privileges to modify HAProxy configuration:
```bash
sudo ./haproxy-gui.sh
```

### Configuration validation fails
- Review error messages in the validation report
- Check HAProxy documentation for correct syntax
- Restore from a previous backup if needed

### HAProxy service not found
Ensure HAProxy is installed:
```bash
# Debian/Ubuntu
sudo apt-get install haproxy

# CentOS/RHEL
sudo yum install haproxy
```

## Documentation

- [Implementation Plan](PLAN.md) - Detailed project plan and architecture
- [Features Documentation](docs/FEATURES.md) - Complete feature reference
- [Usage Guide](docs/USAGE.md) - Comprehensive user guide
- [API Documentation](docs/API.md) - Internal API reference

## Development

### Running Tests
```bash
cd tests
./run-tests.sh
```

### Contributing
Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

### Code Style
- Follow bash best practices
- Use meaningful function names
- Add comments for complex logic
- Keep functions focused and small
- Include error handling

## Roadmap

### Version 1.0 (Current Plan)
- Core functionality (global, defaults, frontend, backend, listen)
- ACL and SSL management
- Validation and backup/restore
- Service control
- Basic templates

### Version 1.1
- Enhanced statistics dashboard
- Log analysis tools
- Configuration diff viewer
- More templates

### Version 2.0
- Multi-file configuration support
- Configuration version control
- Performance recommendations
- Security audit features

## Known Limitations

1. Does not support all HAProxy features (targets 60%+ of main features)
2. Limited to single configuration file (multi-file support planned)
3. Basic syntax highlighting (no color-coded config display yet)
4. No real-time statistics (planned for future release)

## FAQ

**Q: Do I need to restart HAProxy after changes?**
A: No, the application uses HAProxy's graceful reload feature which doesn't drop existing connections.

**Q: Can I use this on remote servers?**
A: Yes, as long as you have SSH access and appropriate permissions.

**Q: Is this safe for production use?**
A: Yes, with proper testing. The application includes safety features like automatic backups and validation. Always test in a non-production environment first.

**Q: Can I edit the config file manually and use this tool?**
A: Yes, the application reads the current configuration each time it starts.

**Q: What HAProxy versions are supported?**
A: HAProxy 1.8+ recommended, though most features work with 1.6+.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: Report bugs at https://github.com/yourusername/haproxy-cli-gui/issues
- **Discussions**: Ask questions in GitHub Discussions
- **Documentation**: Check the docs/ directory

## Acknowledgments

- HAProxy team for excellent documentation
- Dialog/Whiptail maintainers
- Bash community for best practices
- Contributors and users

## Author

Created and maintained by the HAProxy CLI GUI team.

---

**Made with ❤️ for the HAProxy community**
