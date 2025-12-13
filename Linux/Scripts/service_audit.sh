#!/bin/bash
# service_audit.sh
# - Audit running/enabled services, enable/disable critical ones
# - Ensure auditd enabled, manage systemd timers, schedule tasks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/os_misc.sh"

log "[service_audit] Starting service audit."

# List running services and enabled units
systemctl list-units --type=service --state=running > ./service_audit_running.log
systemctl list-unit-files --state=enabled > ./service_audit_enabled.log

# Ensure auditd is enabled and running
if systemctl list-unit-files | grep -qw auditd; then
    systemctl enable auditd || true
    systemctl restart auditd || true
    log "[service_audit] auditd enabled and restarted."
fi

# Ensure important timers are enabled (example: apt-daily)
if systemctl list-unit-files | grep -q apt-daily.timer; then
    systemctl enable apt-daily.timer || true
    systemctl start apt-daily.timer || true
fi

# Provide helper to disable dangerous services (NOT executed automatically)
dangerous_services=(telnet rsh rexec xinetd avahi-daemon)
for svc in "${dangerous_services[@]}"; do
    if systemctl list-unit-files | grep -qw "$svc"; then
        echo "$svc is present; consider disabling it (not done automatically).">> ./service_audit_suggested_disable.log
    fi
done

log "[service_audit] Completed. Check logs in current dir."
