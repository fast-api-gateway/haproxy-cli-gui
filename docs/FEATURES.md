# HAProxy CLI GUI - Features Documentation

## Complete Feature Reference

This document provides detailed information about all features supported by HAProxy CLI GUI, organized by category with examples and usage instructions.

## Table of Contents

1. [Global Configuration](#global-configuration)
2. [Defaults Section](#defaults-section)
3. [Frontend Configuration](#frontend-configuration)
4. [Backend Configuration](#backend-configuration)
5. [Listen Sections](#listen-sections)
6. [ACL Management](#acl-management)
7. [SSL/TLS Configuration](#ssltls-configuration)
8. [Statistics Interface](#statistics-interface)
9. [Logging Configuration](#logging-configuration)
10. [Advanced Features](#advanced-features)
11. [Service Control](#service-control)
12. [Backup & Restore](#backup--restore)

---

## Global Configuration

Global settings affect the entire HAProxy process.

### Supported Directives

#### Process Management
- `daemon` - Run as daemon
- `nbproc` - Number of processes (deprecated in 2.x)
- `nbthread` - Number of threads per process
- `cpu-map` - Bind processes/threads to CPUs

#### User and Group
- `user` - Run as specific user
- `group` - Run as specific group
- `chroot` - Change root directory

#### Connection Limits
- `maxconn` - Maximum concurrent connections
- `tune.maxaccept` - Maximum accepts at once
- `tune.bufsize` - Buffer size tuning

#### Logging
- `log` - Global log targets
- `log-send-hostname` - Include hostname in logs

#### Statistics
- `stats socket` - Stats socket for runtime API
- `stats timeout` - Stats socket timeout

#### SSL/TLS
- `ssl-default-bind-ciphers` - Default cipher list
- `ssl-default-bind-options` - Default SSL options
- `ssl-engine` - Hardware SSL engine
- `ca-base` - CA files directory
- `crt-base` - Certificate files directory

### Example Configuration

```haproxy
global
    daemon
    user haproxy
    group haproxy
    maxconn 4096
    nbthread 4
    log /dev/log local0
    log /dev/log local1 notice
    stats socket /var/run/haproxy.sock mode 600 level admin
    stats timeout 30s
    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private
    ssl-default-bind-ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
```

### UI Navigation
```
Main Menu → Global Settings
├── View global settings
├── Edit max connections
├── Edit user/group
├── Configure logging
├── Configure stats socket
└── Advanced settings
```

---

## Defaults Section

Default values inherited by frontends, backends, and listen sections.

### Supported Directives

#### Mode
- `mode http` - HTTP mode (layer 7)
- `mode tcp` - TCP mode (layer 4)
- `mode health` - Health check mode

#### Timeouts
- `timeout connect` - Connection timeout
- `timeout client` - Client inactivity timeout
- `timeout server` - Server inactivity timeout
- `timeout check` - Health check timeout
- `timeout http-request` - HTTP request timeout
- `timeout http-keep-alive` - HTTP keep-alive timeout
- `timeout queue` - Queue timeout
- `timeout tunnel` - Tunnel timeout

#### Retries
- `retries` - Number of connection retries

#### Options
- `option httplog` - Enable HTTP logging
- `option dontlognull` - Don't log null connections
- `option http-server-close` - Enable server connection close
- `option forwardfor` - Add X-Forwarded-For header
- `option redispatch` - Allow session redistribution on failure

#### HTTP
- `http-reuse` - HTTP connection reuse policy
- `http-check` - HTTP health check method

#### Balance
- `balance` - Default load balancing algorithm

### Example Configuration

```haproxy
defaults
    mode http
    log global
    option httplog
    option dontlognull
    option http-server-close
    option forwardfor except 127.0.0.0/8
    option redispatch
    retries 3
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    timeout http-request 10s
    timeout http-keep-alive 10s
    balance roundrobin
```

### UI Navigation
```
Main Menu → Defaults Section
├── View defaults
├── Edit mode
├── Configure timeouts
├── Edit retry settings
├── Configure options
└── HTTP defaults
```

---

## Frontend Configuration

Frontends define how requests are accepted and routed.

### Supported Directives

#### Bind
- `bind` - Listen address and port
  - Format: `bind [<address>]:<port> [<options>]`
  - SSL: `bind *:443 ssl crt /path/to/cert.pem`
  - Multiple binds supported

#### ACLs
- `acl` - Define access control lists
- Format: `acl <name> <criterion> <value>`

#### Routing
- `use_backend` - Route to backend based on conditions
- `default_backend` - Default backend if no rules match

#### HTTP Headers
- `http-request` - HTTP request modifications
  - `add-header` - Add header
  - `set-header` - Set header
  - `del-header` - Delete header
  - `replace-header` - Replace header
  - `redirect` - HTTP redirect

#### Rate Limiting
- `stick-table` - Define stick table for tracking
- `http-request track-sc0` - Track requests
- `http-request deny` - Deny based on rate

#### Other
- `mode` - Override default mode
- `option httplog` - Enable HTTP logging
- `compression` - Enable compression
- `monitor-uri` - Health check URI

### Example Configuration

```haproxy
frontend http_front
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/example.com.pem
    mode http
    option httplog

    # ACLs
    acl is_api path_beg /api
    acl is_static path_beg /static /images /css /js
    acl is_admin hdr(host) -i admin.example.com

    # Routing
    use_backend api_servers if is_api
    use_backend static_servers if is_static
    use_backend admin_servers if is_admin
    default_backend web_servers

    # Headers
    http-request add-header X-Forwarded-Proto https if { ssl_fc }
    http-request set-header X-Real-IP %[src]

    # Rate limiting
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny if { sc_http_req_rate(0) gt 100 }
```

### UI Navigation
```
Main Menu → Frontend Management
├── List frontends
├── Add new frontend
├── Edit frontend
│   ├── Edit bind addresses
│   ├── Manage ACLs
│   ├── Configure backend routing
│   ├── Set default backend
│   ├── HTTP settings
│   ├── SSL settings
│   └── Advanced options
├── Delete frontend
└── Clone frontend
```

---

## Backend Configuration

Backends define server pools and load balancing.

### Supported Directives

#### Balance Algorithms
- `balance roundrobin` - Round-robin
- `balance leastconn` - Least connections
- `balance source` - Source IP hash
- `balance uri` - URI hash
- `balance url_param` - URL parameter hash
- `balance hdr(<name>)` - HTTP header hash
- `balance rdp-cookie` - RDP cookie hash

#### Server Definitions
- `server` - Define backend server
  - Format: `server <name> <address>:<port> [options]`
  - Options:
    - `check` - Enable health checks
    - `inter <time>` - Check interval
    - `rise <count>` - Required successes
    - `fall <count>` - Required failures
    - `weight <value>` - Server weight
    - `maxconn <value>` - Max connections
    - `backup` - Backup server
    - `ssl` - Use SSL to backend
    - `check-ssl` - SSL health check
    - `verify none/required` - SSL verification

#### Health Checks
- `option httpchk` - HTTP health check
- `option ssl-hello-chk` - SSL hello check
- `option smtpchk` - SMTP check
- `option mysql-check` - MySQL check
- `option pgsql-check` - PostgreSQL check
- `option redis-check` - Redis check

#### Session Persistence
- `cookie` - Cookie-based persistence
- `stick-table` - Stick table for persistence
- `stick on` - Stick on criterion

#### HTTP Settings
- `http-request` - HTTP request modifications
- `http-response` - HTTP response modifications
- `compression` - Enable compression

#### Other
- `mode` - Override default mode
- `option httplog` - Enable HTTP logging
- `errorfile` - Custom error pages

### Example Configuration

```haproxy
backend web_servers
    mode http
    balance roundrobin
    option httpchk GET /health
    http-check expect status 200

    # Session persistence
    cookie SERVERID insert indirect nocache

    # Servers
    server web1 192.168.1.10:8080 check inter 3s rise 2 fall 3 weight 100 cookie web1
    server web2 192.168.1.11:8080 check inter 3s rise 2 fall 3 weight 100 cookie web2
    server web3 192.168.1.12:8080 check inter 3s rise 2 fall 3 weight 50 cookie web3
    server web4 192.168.1.13:8080 check inter 3s rise 2 fall 3 backup

    # HTTP modifications
    http-request set-header X-Backend web_servers
    http-response set-header X-Cache-Status HIT

backend api_servers
    mode http
    balance leastconn
    option httpchk GET /api/health
    http-check expect string "ok"

    server api1 192.168.2.10:8000 check maxconn 1000
    server api2 192.168.2.11:8000 check maxconn 1000
    server api3 192.168.2.12:8000 check maxconn 1000

backend ssl_backend
    mode http
    balance roundrobin
    option httpchk GET /

    server secure1 192.168.3.10:443 check ssl verify none
    server secure2 192.168.3.11:443 check ssl verify none
```

### UI Navigation
```
Main Menu → Backend Management
├── List backends
├── Add new backend
├── Edit backend
│   ├── Edit balance algorithm
│   ├── Manage servers
│   │   ├── Add server
│   │   ├── Edit server
│   │   ├── Delete server
│   │   └── Configure health checks
│   ├── Configure persistence
│   ├── HTTP options
│   ├── SSL backend settings
│   └── Advanced options
├── Delete backend
└── Clone backend
```

---

## Listen Sections

Combined frontend and backend in one section.

### Use Cases
- Simple load balancing
- Statistics interface
- Quick setups

### Example Configuration

```haproxy
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
    stats auth admin:password
    stats admin if TRUE

listen mysql_cluster
    bind *:3306
    mode tcp
    option mysql-check user haproxy
    balance leastconn
    server mysql1 192.168.4.10:3306 check
    server mysql2 192.168.4.11:3306 check backup

listen redis_cluster
    bind *:6379
    mode tcp
    option tcp-check
    tcp-check send PING\r\n
    tcp-check expect string +PONG
    balance first
    server redis1 192.168.5.10:6379 check inter 1s
    server redis2 192.168.5.11:6379 check inter 1s
```

### UI Navigation
```
Main Menu → Listen Sections
├── List listen sections
├── Add new listen
├── Edit listen
├── Delete listen
└── Configure stats interface
```

---

## ACL Management

ACLs enable flexible request routing and filtering.

### ACL Types

#### Path-based
```haproxy
acl is_api path_beg /api
acl is_static path_end .jpg .png .css .js
acl is_blog path_dir blog
acl url_search path_reg ^/search\?
```

#### Host-based
```haproxy
acl host_example hdr(host) -i example.com
acl host_www hdr(host) -i www.example.com
acl host_admin hdr(host) -i admin.example.com
acl host_api hdr_beg(host) -i api.
```

#### Method-based
```haproxy
acl is_get method GET
acl is_post method POST
acl is_write method POST PUT DELETE
```

#### Header-based
```haproxy
acl has_auth hdr_cnt(Authorization) gt 0
acl is_ajax hdr(X-Requested-With) -i XMLHttpRequest
acl has_cookie hdr_cnt(Cookie) gt 0
```

#### IP-based
```haproxy
acl local_network src 192.168.0.0/16
acl trusted_ips src 10.0.1.10 10.0.1.11 10.0.1.12
acl private_network src 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
```

#### Content-based
```haproxy
acl has_session req.cook(SESSIONID) -m found
acl is_mobile hdr_sub(User-Agent) -i mobile android iphone
```

### ACL Operators
- `-i` - Case insensitive
- `-m` - Match method (found, str, beg, end, sub, reg)
- `gt`, `ge`, `lt`, `le`, `eq` - Numeric comparison
- `!` - Negation

### ACL Combinations
```haproxy
# AND
use_backend admin_backend if is_admin has_auth

# OR
use_backend static_backend if is_static or is_media

# NOT
use_backend default_backend if !is_admin !is_static

# Complex
use_backend api_backend if is_api is_post has_auth
```

### UI Navigation
```
Main Menu → ACL Management
├── List all ACLs
├── Add ACL
├── Edit ACL
├── Delete ACL
├── Test ACL expression
└── ACL templates (common patterns)
```

---

## SSL/TLS Configuration

Comprehensive SSL/TLS support for secure connections.

### Frontend SSL (Termination)

#### Basic SSL
```haproxy
frontend https_front
    bind *:443 ssl crt /etc/ssl/certs/example.com.pem
    mode http
    default_backend web_servers
```

#### Multiple Certificates (SNI)
```haproxy
frontend https_front
    bind *:443 ssl crt /etc/ssl/certs/ alpn h2,http/1.1
    mode http
    # HAProxy loads all .pem files from directory
    default_backend web_servers
```

#### SSL Options
```haproxy
frontend https_front
    bind *:443 ssl crt /etc/ssl/certs/example.com.pem \
        ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384 \
        ssl-min-ver TLSv1.2 \
        curves secp384r1:secp256r1 \
        alpn h2,http/1.1
```

#### Client Certificate Authentication
```haproxy
frontend https_front
    bind *:443 ssl crt /etc/ssl/certs/server.pem ca-file /etc/ssl/certs/ca.pem verify required
    mode http
    http-request deny unless { ssl_c_verify 0 }
    default_backend web_servers
```

### Backend SSL

#### SSL to Backend
```haproxy
backend secure_backend
    mode http
    server secure1 192.168.1.10:443 ssl verify none
    server secure2 192.168.1.11:443 ssl verify none
```

#### SSL with Verification
```haproxy
backend secure_backend
    mode http
    server secure1 192.168.1.10:443 ssl verify required ca-file /etc/ssl/certs/ca.pem
```

### SSL ACLs
```haproxy
acl is_ssl ssl_fc
acl has_sni ssl_fc_sni -m found
acl cert_valid ssl_c_verify 0
acl strong_cipher ssl_fc_cipher -m sub AES256-GCM
```

### UI Navigation
```
Main Menu → SSL/TLS Configuration
├── List SSL certificates
├── Configure SSL bind options
├── Configure SSL ciphers
├── SNI configuration
└── Backend SSL settings
```

---

## Statistics Interface

Built-in statistics and monitoring.

### Stats Configuration

#### Basic Stats
```haproxy
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 30s
```

#### Stats with Authentication
```haproxy
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats realm HAProxy\ Statistics
    stats auth admin:password
    stats auth readonly:readonly
```

#### Stats with Admin Access
```haproxy
listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats auth admin:securepassword
    stats admin if TRUE
    stats hide-version
```

### Stats Features
- Real-time connection statistics
- Server health status
- Request rate graphs
- Error counters
- Session management
- Enable/disable servers
- Drain servers
- Set server weights

### UI Navigation
```
Main Menu → Statistics Interface
├── Enable/disable stats
├── Configure stats URI
├── Set authentication
├── Configure options
└── View live stats (if enabled)
```

---

## Logging Configuration

Flexible logging configuration.

### Log Targets
```haproxy
global
    log /dev/log local0
    log 127.0.0.1:514 local1 notice
    log 192.168.1.100:514 local2 warning
```

### Log Formats

#### HTTP Log
```haproxy
defaults
    option httplog
    log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r"
```

#### Custom Log Format
```haproxy
defaults
    log-format "%{+Q}o\ %{-Q}ci\ -\ -\ [%trg]\ %r\ %ST\ %B\ \"\"\ \"\"\ %cp\ %ms\ %ft\ %b\ %s\ %TR\ %Tw\ %Tc\ %Tr\ %Ta\ %tsc\ %ac\ %fc\ %bc\ %sc\ %rc\ %sq\ %bq\ %CC\ %CS\ %hrl\ %hsl"
```

### UI Navigation
```
Main Menu → Logging Configuration
├── Configure log targets
├── Set log format
├── Configure log level
└── Custom log format
```

---

## Advanced Features

### Compression

```haproxy
frontend http_front
    bind *:80
    compression algo gzip
    compression type text/html text/plain text/css text/javascript application/javascript application/json
    compression offload
    default_backend web_servers
```

### Rate Limiting

```haproxy
frontend http_front
    bind *:80

    # Track requests by IP
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src

    # Deny if more than 100 requests in 10 seconds
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }
```

### HTTP/2

```haproxy
frontend https_front
    bind *:443 ssl crt /etc/ssl/certs/example.com.pem alpn h2,http/1.1
    mode http
    default_backend web_servers
```

### Error Pages

```haproxy
defaults
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http
```

### Connection Limits

```haproxy
frontend http_front
    bind *:80
    maxconn 10000

backend web_servers
    server web1 192.168.1.10:8080 maxconn 1000
    server web2 192.168.1.11:8080 maxconn 1000
```

### UI Navigation
```
Main Menu → Advanced Features
├── Rate limiting
├── Compression
├── Stick tables
├── Error pages
├── HTTP/2 settings
└── Connection limits
```

---

## Service Control

Manage HAProxy service directly from the GUI.

### Available Operations

#### Check Status
```bash
systemctl status haproxy
# or
service haproxy status
```

#### Reload Configuration
```bash
systemctl reload haproxy
# or
service haproxy reload
```

#### Restart Service
```bash
systemctl restart haproxy
# or
service haproxy restart
```

#### Stop Service
```bash
systemctl stop haproxy
# or
service haproxy stop
```

#### View Logs
```bash
journalctl -u haproxy -n 100 -f
# or
tail -f /var/log/haproxy.log
```

### UI Navigation
```
Main Menu → Service Control
├── Check HAProxy status
├── Reload configuration
├── Restart HAProxy
├── Stop HAProxy
└── View logs
```

---

## Backup & Restore

Comprehensive backup and restore functionality.

### Automatic Backups
- Created before every modification
- Timestamped: `haproxy.cfg.backup.20240115_103045`
- Stored in configurable location (default: `./backups/`)

### Manual Backups
- Create on-demand backups
- Add custom notes/labels
- Export to different location

### Restore Options
- List all available backups
- Preview backup contents
- Compare with current config
- Restore selected backup

### Backup Retention
- Configurable retention period
- Automatic cleanup of old backups
- Keep important backups permanently

### UI Navigation
```
Main Menu → Backup & Restore
├── Create backup
├── List backups
├── Restore from backup
├── Delete backup
└── Compare configs
```

---

## Feature Coverage Summary

| Category | Features | Coverage |
|----------|----------|----------|
| Global Settings | 15+ directives | 90% |
| Defaults | 20+ directives | 85% |
| Frontend | 25+ directives | 80% |
| Backend | 30+ directives | 85% |
| Listen | All features | 100% |
| ACLs | 20+ criteria | 75% |
| SSL/TLS | 15+ options | 80% |
| Stats | All features | 100% |
| Logging | All features | 100% |
| Advanced | 10+ features | 60% |

**Overall Coverage: ~80% of HAProxy features**

---

## Limitations

Features not currently supported:
1. Maps and map files
2. Lua scripting
3. SPOE (Stream Processing Offload Engine)
4. DeviceAtlas integration
5. 51Degrees integration
6. Custom converters and fetches
7. External health check programs
8. DNS resolution configuration
9. Email alerts
10. Peers (configuration synchronization)

These features may be added in future versions based on user demand.

---

## Getting Help

For detailed usage instructions, see [USAGE.md](USAGE.md).
For architecture details, see [ARCHITECTURE.md](ARCHITECTURE.md).
For the main README, see [README.md](../README.md).
