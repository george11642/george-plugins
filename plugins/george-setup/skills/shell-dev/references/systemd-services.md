# systemd Services and Timers for Shell Scripts

Complete guide to wrapping shell scripts in systemd services and timers.

---

## 1. Basic Service Unit File

Create `/etc/systemd/system/myapp.service` (system) or `~/.config/systemd/user/myapp.service` (user):

```ini
[Unit]
Description=My Application Service
Documentation=https://example.com/docs
# Ordering: start after network and syslog are ready
After=network.target syslog.target
# Strong dependency: if postgresql fails, this unit fails too
Requires=postgresql.service
# Weak dependency: try to start redis, but continue without it
Wants=redis.service

[Service]
Type=simple
# Absolute path required; do not use shell expansion
ExecStart=/usr/local/bin/myapp --config /etc/myapp/config.yml

# Restart behavior
Restart=on-failure          # Restart only on non-zero exit or signal
RestartSec=5s               # Wait 5 seconds before restart
StartLimitIntervalSec=60s   # Over 60-second window...
StartLimitBurst=3           # ...allow 3 restart attempts

# User/group to run as (creates security boundary)
User=myapp
Group=myapp

# Working directory
WorkingDirectory=/var/lib/myapp

# Environment variables
Environment="APP_ENV=production"
Environment="APP_PORT=8080"
# Or load from a file (one KEY=VALUE per line)
EnvironmentFile=/etc/myapp/env

# Resource limits
LimitNOFILE=65536           # Max open file descriptors

[Install]
WantedBy=multi-user.target
```

### Service Types

| Type | Use Case |
|------|----------|
| `simple` | Process stays in foreground (default). systemd tracks the main PID. |
| `forking` | Process daemonizes (double-fork). Set `PIDFile=`. |
| `oneshot` | Short-lived task; systemd waits for exit. Use with `RemainAfterExit=yes`. |
| `notify` | Process sends `sd_notify(READY=1)` when ready. |
| `exec` | Like `simple` but systemd waits for `execve()` to succeed. |

---

## 2. Complete Long-Running Service Example

```ini
# /etc/systemd/system/myworker.service
[Unit]
Description=My Background Worker
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/myapp/bin/worker.sh
ExecReload=/bin/kill -HUP $MAINPID   # Reload config on SIGHUP
ExecStop=/bin/kill -TERM $MAINPID    # Graceful stop

# Restart configuration
Restart=always
RestartSec=10s
StartLimitIntervalSec=300
StartLimitBurst=5

# Security hardening
User=worker
Group=worker
NoNewPrivileges=yes
PrivateTmp=yes                        # Isolated /tmp
ProtectSystem=strict                  # Read-only system dirs
ReadWritePaths=/var/lib/myapp /var/log/myapp

# Logging — all stdout/stderr goes to journald automatically
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myworker             # Tag for journalctl filtering

# Environment
Environment=HOME=/var/lib/myapp
EnvironmentFile=-/etc/myapp/env       # Leading - means optional

[Install]
WantedBy=multi-user.target
```

---

## 3. Oneshot Service (run-and-complete tasks)

```ini
# /etc/systemd/system/db-migrate.service
[Unit]
Description=Database Migration
After=postgresql.service
Requires=postgresql.service

[Service]
Type=oneshot
RemainAfterExit=yes           # Unit shows "active" after script exits 0
ExecStart=/opt/myapp/bin/migrate.sh up
ExecStop=/opt/myapp/bin/migrate.sh down

User=myapp
WorkingDirectory=/opt/myapp

StandardOutput=journal
StandardError=journal
SyslogIdentifier=db-migrate
```

---

## 4. systemd Timers (cron replacement)

Timers are `.timer` units that activate a corresponding `.service` unit.

### Calendar Timer (cron-like)

```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily Backup Timer
Requires=backup.service

[Timer]
# Run at 2:30 AM every day
OnCalendar=*-*-* 02:30:00
# Run missed executions if system was down
Persistent=true
# Random delay up to 15 minutes to avoid thundering herd
RandomizedDelaySec=15min

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Daily Backup Job
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/scripts/backup.sh
User=backup
StandardOutput=journal
SyslogIdentifier=backup
```

### OnCalendar Syntax Examples

```
OnCalendar=daily              # Midnight every day
OnCalendar=weekly             # Monday midnight
OnCalendar=monthly            # 1st of month midnight
OnCalendar=hourly             # Every hour at :00
OnCalendar=*:0/15             # Every 15 minutes
OnCalendar=Mon-Fri 09:00      # Weekdays at 9am
OnCalendar=*-*-* 00/6:00:00   # Every 6 hours
OnCalendar=Sat *-*-1..7 18:00 # First Saturday of each month 6pm
```

### Boot/Elapsed Time Timer

```ini
[Timer]
# 5 minutes after system boot
OnBootSec=5min
# Then every 30 minutes after the service last ran
OnUnitActiveSec=30min
```

### Verify Timer

```bash
systemd-analyze calendar "Mon-Fri 09:00"   # Test calendar expression
systemctl list-timers --all                  # Show all timers and next trigger
```

---

## 5. Service Lifecycle Commands

```bash
# Reload daemon after editing unit files (ALWAYS required)
sudo systemctl daemon-reload

# Enable at boot (creates symlink in wants directory)
sudo systemctl enable myapp.service

# Enable AND start immediately
sudo systemctl enable --now myapp.service

# Start/stop/restart
sudo systemctl start   myapp.service
sudo systemctl stop    myapp.service
sudo systemctl restart myapp.service

# Reload config without restart (sends SIGHUP if ExecReload defined)
sudo systemctl reload myapp.service

# Check status (shows recent log lines)
systemctl status myapp.service

# Disable from autostart
sudo systemctl disable myapp.service

# Remove completely (disable + mask prevents any start)
sudo systemctl mask myapp.service
```

---

## 6. PID File Management

For `Type=forking` services where the process daemonizes:

```ini
[Service]
Type=forking
PIDFile=/run/myapp/myapp.pid
ExecStart=/usr/local/bin/myapp --daemonize --pidfile /run/myapp/myapp.pid
RuntimeDirectory=myapp         # Creates /run/myapp, chowned to User=
RuntimeDirectoryMode=0755
```

In the shell script:

```bash
#!/bin/bash
PIDFILE="/run/myapp/myapp.pid"

# Write PID file
echo $$ > "$PIDFILE"

# Cleanup on exit
cleanup() {
    rm -f "$PIDFILE"
    echo "Service stopped" | logger -t myapp
}
trap cleanup EXIT SIGTERM SIGINT
```

---

## 7. Graceful Shutdown with SIGTERM Handler

```bash
#!/bin/bash
set -Eeuo pipefail

STOP_REQUESTED=false
WORKERS=()

cleanup() {
    echo "Received shutdown signal, draining work queue..." | logger -t myapp -p user.info
    STOP_REQUESTED=true

    # Wait for all background workers to finish (max 30 seconds)
    local timeout=30
    local waited=0
    while [[ ${#WORKERS[@]} -gt 0 ]] && [[ $waited -lt $timeout ]]; do
        # Remove completed workers from list
        local alive=()
        local pid
        for pid in "${WORKERS[@]}"; do
            kill -0 "$pid" 2>/dev/null && alive+=("$pid")
        done
        WORKERS=("${alive[@]}")
        sleep 1
        ((waited++))
    done

    # Force kill remaining workers if timeout exceeded
    local pid
    for pid in "${WORKERS[@]}"; do
        echo "Force killing worker PID $pid" | logger -t myapp -p user.warn
        kill -KILL "$pid" 2>/dev/null || true
    done

    echo "Shutdown complete" | logger -t myapp -p user.info
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

# Main loop
while ! $STOP_REQUESTED; do
    process_one_item &
    WORKERS+=($!)

    # Reap completed children
    wait -n 2>/dev/null || true
    sleep 1
done

wait   # Wait for all remaining background jobs
```

---

## 8. Journald Logging Integration

Shell scripts can write structured logs to journald:

```bash
# Basic: use logger command
logger -t "myapp" -p user.info "Server started on port 8080"
logger -t "myapp" -p user.err  "Database connection failed: $error"

# Map log levels to syslog priorities
log_info()  { logger -t "myapp" -p user.info  "$*"; }
log_warn()  { logger -t "myapp" -p user.warn  "$*"; }
log_error() { logger -t "myapp" -p user.err   "$*"; }
log_debug() { logger -t "myapp" -p user.debug "$*"; }

# Structured journald fields (systemd-cat)
echo "Starting backup job" | systemd-cat -t "backup" -p info
echo "Backup failed"       | systemd-cat -t "backup" -p err

# Multi-field structured logging via journald socket
# Requires: journald socket support (most modern systemd)
systemd-cat -t myapp <<< "MESSAGE=backup completed FILES=42 DURATION=12s"

# From within a service: stdout/stderr go to journal automatically
# Use prefixes to control log level (with journald StandardOutput=journal+console):
# No prefix = info, # "warning: " = warning, "error: " = error
```

### Reading Logs

```bash
# All logs for a unit
journalctl -u myapp.service

# Follow (like tail -f)
journalctl -u myapp.service -f

# Since last boot
journalctl -u myapp.service -b

# Time range
journalctl -u myapp.service --since "2024-01-01 00:00" --until "2024-01-02 00:00"

# Last N lines
journalctl -u myapp.service -n 100

# Priority filter (errors and above)
journalctl -u myapp.service -p err

# JSON output for parsing
journalctl -u myapp.service -o json | jq .MESSAGE
```

---

## 9. User Services (no root required)

```bash
# Create user service directory
mkdir -p ~/.config/systemd/user/

# Copy unit file there
cp myapp.service ~/.config/systemd/user/

# Control (no sudo needed!)
systemctl --user daemon-reload
systemctl --user enable --now myapp.service
systemctl --user status myapp.service
journalctl --user -u myapp.service -f

# Enable lingering: keep user services running after logout
loginctl enable-linger "$USER"
```

---

## 10. Debugging Service Failures

```bash
# Check why a service failed to start
systemctl status myapp.service -l    # -l shows full log lines

# View all journal output (including early startup)
journalctl -u myapp.service -b --no-pager

# Check the unit file as parsed by systemd
systemctl cat myapp.service

# Verify the unit file has no syntax errors
systemd-analyze verify myapp.service

# Show service property values
systemctl show myapp.service | grep -E "^(ActiveState|SubState|ExecStart|Restart)"

# Run service command manually as the service user (debugging)
sudo -u myapp /usr/local/bin/myapp --config /etc/myapp/config.yml

# Check override/drop-in files
systemctl cat myapp.service   # Shows all merged unit files
ls /etc/systemd/system/myapp.service.d/   # Drop-in directory
```

---

## 11. Drop-in Overrides (modify without editing original)

```bash
# Create override without editing the original unit
sudo systemctl edit myapp.service   # Opens editor, creates drop-in

# Override specific settings:
# /etc/systemd/system/myapp.service.d/override.conf
[Service]
# Clear the original ExecStart first (required to override ExecStart)
ExecStart=
ExecStart=/usr/local/bin/myapp --config /etc/myapp/config.yml --debug
Environment=APP_LOG_LEVEL=debug
```

---

## Complete Example: Web App Service + Timer

```ini
# /etc/systemd/system/webapp.service
[Unit]
Description=My Web Application
After=network-online.target postgresql.service
Wants=network-online.target
Requires=postgresql.service

[Service]
Type=notify                  # App sends sd_notify when ready
ExecStart=/opt/webapp/bin/server
ExecReload=/bin/kill -USR1 $MAINPID
Restart=on-failure
RestartSec=5s
User=webapp
Group=webapp
WorkingDirectory=/opt/webapp
RuntimeDirectory=webapp
StateDirectory=webapp
LogsDirectory=webapp
EnvironmentFile=/etc/webapp/env
StandardOutput=journal
StandardError=journal
SyslogIdentifier=webapp
# Hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes

[Install]
WantedBy=multi-user.target
```

```ini
# /etc/systemd/system/webapp-cleanup.timer
[Unit]
Description=Clean up old webapp sessions daily

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/webapp-cleanup.service
[Unit]
Description=Clean up old webapp sessions

[Service]
Type=oneshot
ExecStart=/opt/webapp/bin/cleanup.sh --older-than 7d
User=webapp
StandardOutput=journal
SyslogIdentifier=webapp-cleanup
```
