# Quick Start Guide

Get started with HAProxy CLI GUI in minutes.

## Installation

### 1. Prerequisites Check

```bash
# Check bash version (need 4.0+)
bash --version

# Check if dialog is installed
which dialog || which whiptail

# Check if haproxy is installed
which haproxy
haproxy -v
```

### 2. Install Missing Dependencies

**Debian/Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install -y bash dialog haproxy
```

**CentOS/RHEL:**
```bash
sudo yum install -y bash dialog haproxy
```

**macOS:**
```bash
brew install bash dialog haproxy
```

### 3. Clone and Setup

```bash
# Clone repository
git clone https://github.com/yourusername/haproxy-cli-gui.git
cd haproxy-cli-gui

# Make executable
chmod +x haproxy-gui.sh

# Optional: Create symbolic link for easy access
sudo ln -s $(pwd)/haproxy-gui.sh /usr/local/bin/haproxy-gui
```

## First Run

### Launch the Application

```bash
# Run with sudo (needed for config file access)
sudo ./haproxy-gui.sh

# Or if you created the symlink
sudo haproxy-gui
```

### Main Menu Overview

```
╔══════════════════════════════════════════════════════════╗
║              HAProxy Configuration Manager               ║
╠══════════════════════════════════════════════════════════╣
║  1. View Current Configuration                          ║
║  2. Global Settings                                     ║
║  3. Defaults Section                                    ║
║  4. Frontend Management                                 ║
║  5. Backend Management                                  ║
║  6. Listen Sections                                     ║
║  7. ACL Management                                      ║
║  8. SSL/TLS Configuration                               ║
║  9. Statistics Interface                                ║
║  10. Logging Configuration                              ║
║  11. Advanced Features                                  ║
║  12. Templates                                          ║
║  13. Validation & Testing                               ║
║  14. Backup & Restore                                   ║
║  15. Service Control                                    ║
║  16. Configuration File                                 ║
║  17. Help & About                                       ║
║  18. Exit                                               ║
╚══════════════════════════════════════════════════════════╝
```

## Basic Workflows

### Workflow 1: View Current Configuration

1. Launch application
2. Select **"1. View Current Configuration"**
3. Choose display option:
   - Full configuration
   - By section type
   - Export to file

### Workflow 2: Add a Simple HTTP Load Balancer

#### Step 1: Create Frontend

1. Main Menu → **"4. Frontend Management"**
2. Select **"Add new frontend"**
3. Enter details:
   ```
   Name: web_front
   Bind address: *:80
   Mode: http
   Default backend: web_servers
   ```
4. Confirm and save

#### Step 2: Create Backend

1. Main Menu → **"5. Backend Management"**
2. Select **"Add new backend"**
3. Enter details:
   ```
   Name: web_servers
   Mode: http
   Balance algorithm: roundrobin
   ```
4. Select **"Manage servers"** → **"Add server"**
5. Add three servers:
   ```
   Server 1:
     Name: web1
     Address: 192.168.1.10:8080
     Options: check

   Server 2:
     Name: web2
     Address: 192.168.1.11:8080
     Options: check

   Server 3:
     Name: web3
     Address: 192.168.1.12:8080
     Options: check
   ```
6. Save backend

#### Step 3: Validate and Apply

1. Main Menu → **"13. Validation & Testing"**
2. Select **"Validate current config"**
3. Review validation results
4. Main Menu → **"15. Service Control"**
5. Select **"Reload configuration"**

**Done!** HAProxy is now load balancing HTTP traffic across three servers.

### Workflow 3: Add SSL Termination

#### Step 1: Prepare SSL Certificate

```bash
# Ensure certificate is in PEM format and readable
sudo chmod 600 /etc/ssl/certs/example.com.pem
```

#### Step 2: Create HTTPS Frontend

1. Main Menu → **"4. Frontend Management"**
2. Select **"Add new frontend"**
3. Enter details:
   ```
   Name: https_front
   Bind address: *:443 ssl crt /etc/ssl/certs/example.com.pem
   Mode: http
   Default backend: web_servers
   ```
4. Save frontend

#### Step 3: Add HTTP to HTTPS Redirect (Optional)

1. Edit the HTTP frontend (`web_front`)
2. Add ACL:
   ```
   Name: is_ssl
   Criterion: ssl_fc
   ```
3. Add redirect rule:
   ```
   http-request redirect scheme https unless is_ssl
   ```

#### Step 4: Apply Changes

1. Validate configuration
2. Reload HAProxy

**Done!** HTTPS is now enabled with automatic HTTP→HTTPS redirect.

### Workflow 4: Configure Statistics Interface

1. Main Menu → **"9. Statistics Interface"**
2. Select **"Enable stats"**
3. Configure:
   ```
   Stats URI: /haproxy-stats
   Port: 8404
   Username: admin
   Password: SecurePass123
   Enable admin mode: Yes
   ```
4. Save and reload

5. Access stats at: `http://your-server:8404/haproxy-stats`

### Workflow 5: Add Path-Based Routing

#### Step 1: Define ACLs

1. Main Menu → **"7. ACL Management"** or edit frontend
2. Add ACLs:
   ```
   ACL 1:
     Name: is_api
     Criterion: path_beg
     Value: /api

   ACL 2:
     Name: is_admin
     Criterion: path_beg
     Value: /admin
   ```

#### Step 2: Create Backends

Create two backends:
- `api_servers` with API server pool
- `admin_servers` with admin server pool

#### Step 3: Configure Routing

1. Edit frontend
2. Add routing rules:
   ```
   use_backend api_servers if is_api
   use_backend admin_servers if is_admin
   default_backend web_servers
   ```

#### Step 4: Apply

1. Validate and reload

**Done!** Requests are now routed based on URL path.

### Workflow 6: Create Backup and Restore

#### Create Backup

1. Main Menu → **"14. Backup & Restore"**
2. Select **"Create backup"**
3. Enter optional note/description
4. Backup created with timestamp

#### Restore from Backup

1. Main Menu → **"14. Backup & Restore"**
2. Select **"List backups"**
3. Choose backup to restore
4. Confirm restoration
5. Reload HAProxy

### Workflow 7: Use Template for Quick Setup

1. Main Menu → **"12. Templates"**
2. Select template:
   - **Basic**: Simple HTTP load balancer
   - **HTTP LB**: Full HTTP load balancing
   - **SSL**: SSL termination setup
   - **Advanced**: Complex multi-frontend setup
3. Customize template settings
4. Apply template
5. Validate and reload

## Navigation Tips

### Keyboard Shortcuts

- **Arrow Keys**: Navigate menu items
- **Enter**: Select item
- **ESC**: Go back / Cancel
- **Tab**: Move between form fields
- **Space**: Toggle checkboxes/radio buttons

### Menu Navigation

```
Main Menu
    ├─> Submenu
    │   ├─> Option 1
    │   ├─> Option 2
    │   └─> Back to Main Menu (ESC)
    │
    └─> Another Submenu
        └─> ...
```

### Dialog Types

1. **Menu**: List of options (use arrows + Enter)
2. **Form**: Multiple input fields (Tab between fields)
3. **Input**: Single text input (type and Enter)
4. **Yes/No**: Confirmation (select and Enter)
5. **Checklist**: Multiple selection (Space to toggle, Enter to confirm)
6. **Radiolist**: Single selection (Space to select, Enter to confirm)

## Common Tasks

### Change Configuration File Path

1. Main Menu → **"16. Configuration File"**
2. Select **"Change config file path"**
3. Enter new path (e.g., `/opt/haproxy/haproxy.cfg`)
4. Confirm change

### Enable Debug Mode

```bash
# Run with debug output
export DEBUG=1
sudo ./haproxy-gui.sh
```

### Check HAProxy Service Status

1. Main Menu → **"15. Service Control"**
2. Select **"Check HAProxy status"**
3. View service status and info

### View HAProxy Logs

1. Main Menu → **"15. Service Control"**
2. Select **"View logs"**
3. See recent HAProxy log entries

## Troubleshooting

### Issue: "Permission denied"

**Solution**: Run with sudo
```bash
sudo ./haproxy-gui.sh
```

### Issue: "dialog: command not found"

**Solution**: Install dialog
```bash
# Debian/Ubuntu
sudo apt-get install dialog

# CentOS/RHEL
sudo yum install dialog
```

### Issue: "Configuration validation failed"

**Steps**:
1. Review error message
2. Check HAProxy syntax
3. Restore from backup if needed:
   - Main Menu → Backup & Restore → Restore

### Issue: "Cannot connect to HAProxy stats"

**Check**:
1. Stats enabled in configuration
2. Correct port and URI
3. Firewall allows access
4. HAProxy service running

### Issue: "Changes not applied"

**Solution**:
1. Check validation passed
2. Reload HAProxy:
   - Main Menu → Service Control → Reload
3. Check HAProxy logs for errors

## Best Practices

### 1. Always Backup Before Changes
- Automatic backups are created
- Create manual backup for major changes
- Keep important backups

### 2. Validate Before Applying
- Use validation tool before reload
- Review validation output
- Fix errors before proceeding

### 3. Test in Non-Production First
- Test configuration changes
- Verify functionality
- Then apply to production

### 4. Use Descriptive Names
- Frontend: `http_front`, `api_front`, `admin_front`
- Backend: `web_servers`, `api_servers`, `db_pool`
- Clear names help maintenance

### 5. Document Your Changes
- Add comments in config (if editing manually)
- Use backup notes/descriptions
- Maintain change log

### 6. Monitor Statistics
- Enable stats interface
- Check server health regularly
- Monitor error rates

### 7. Regular Backups
- Create backups before changes
- Test restore procedures
- Keep backup history

## Next Steps

1. **Explore Features**: Navigate through all menus to familiarize yourself
2. **Read Documentation**: Check out [FEATURES.md](FEATURES.md) for detailed feature info
3. **Review Examples**: See [PLAN.md](../PLAN.md) for configuration examples
4. **Join Community**: Ask questions, report issues
5. **Contribute**: Submit improvements and bug fixes

## Getting Help

- **Documentation**: `docs/` directory
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **HAProxy Docs**: https://www.haproxy.org/

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────┐
│                    Quick Reference                       │
├─────────────────────────────────────────────────────────┤
│ Launch:          sudo ./haproxy-gui.sh                  │
│ Add Frontend:    Menu → 4 → Add                         │
│ Add Backend:     Menu → 5 → Add                         │
│ Add Server:      Backend → Edit → Manage Servers        │
│ Validate:        Menu → 13 → Validate                   │
│ Reload:          Menu → 15 → Reload                     │
│ Backup:          Menu → 14 → Create backup              │
│ Restore:         Menu → 14 → Restore                    │
│ Stats:           Menu → 9 → Enable stats                │
│ Templates:       Menu → 12 → Load template              │
│ Exit:            Menu → 18 or ESC from main menu        │
└─────────────────────────────────────────────────────────┘
```

---

**Happy HAProxy Configuration! 🚀**
