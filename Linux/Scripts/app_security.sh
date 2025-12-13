#!/bin/bash
# app_security.sh
# - Application & service-level security hardening
# - No antivirus / malware scanning
# - Interactive prompts before risky changes
# - Safe defaults, non-destructive where possible

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/os_misc.sh"

log "[app_security] Starting application and service security hardening."

############################################
# Helper: confirm before risky actions
############################################
confirm_long() {
    echo
    echo "⚠  NOTE: This step may take time or affect running services."
    prompt_continue "Do you want to continue with this step?"
}

############################################
# SSH SERVICE HARDENING
############################################
log "[app_security] SSH hardening checks."

if confirm_long; then
    SSHD_CONFIG="/etc/ssh/sshd_config"

    if [[ -f "$SSHD_CONFIG" ]]; then
        log_info "Checking SSH configuration (no restart yet)."

        grep -q "^PermitRootLogin no" "$SSHD_CONFIG" \
            || log_info "Consider setting: PermitRootLogin no"

        grep -q "^PasswordAuthentication no" "$SSHD_CONFIG" \
            || log_info "Consider setting: PasswordAuthentication no (keys only)"

        grep -q "^Protocol 2" "$SSHD_CONFIG" \
            || log_info "Ensure SSH Protocol 2 is enforced"

        grep -q "^X11Forwarding no" "$SSHD_CONFIG" \
            || log_info "Consider disabling X11Forwarding"

        log_info "SSH hardening review complete (manual edit recommended)."
    else
        log_info "sshd_config not found; skipping SSH hardening."
    fi
else
    log_info "SSH hardening skipped by user."
fi

############################################
# SYSTEM SERVICES HARDENING
############################################
log "[app_security] Reviewing enabled system services."

if confirm_long; then
    systemctl list-unit-files --type=service --state=enabled \
        > ./enabled_services.log

    log_info "Enabled services saved to ./enabled_services.log"
    log_info "Review for unnecessary services (e.g., cups, avahi, rpcbind)."
else
    log_info "Service review skipped."
fi

############################################
# FIREWALL STATUS CHECK (NON-DESTRUCTIVE)
############################################
log "[app_security] Firewall status check."

if command -v ufw >/dev/null 2>&1; then
    ufw status verbose > ./ufw_status.log 2>&1
    log_info "UFW detected. Status written to ./ufw_status.log"
else
    log_info "UFW not installed. No firewall changes made."
fi

############################################
# WEB SERVER HARDENING (Apache / Nginx)
############################################
log "[app_security] Web server hardening checks."

if confirm_long; then
    if systemctl is-active --quiet apache2; then
        log_info "Apache detected."

        APACHE_CONF="/etc/apache2/conf-enabled/security.conf"
        [[ -f "$APACHE_CONF" ]] && grep -E "ServerTokens|ServerSignature" "$APACHE_CONF" \
            || log_info "Consider setting ServerTokens Prod and ServerSignature Off"
    fi

    if systemctl is-active --quiet nginx; then
        log_info "Nginx detected."

        grep -R "server_tokens" /etc/nginx 2>/dev/null \
            || log_info "Consider setting: server_tokens off;"
    fi
else
    log_info "Web server hardening skipped."
fi

############################################
# DATABASE SERVICE HARDENING
############################################
log "[app_security] Database service checks."

if confirm_long; then
    if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
        log_info "MySQL/MariaDB detected."
        log_info "Ensure:"
        log_info "  - No anonymous users"
        log_info "  - Root login restricted"
        log_info "  - bind-address not 0.0.0.0 unless required"
    fi

    if systemctl is-active --quiet postgresql; then
        log_info "PostgreSQL detected."
        log_info "Ensure pg_hba.conf enforces strong auth and no trust entries."
    fi
else
    log_info "Database hardening skipped."
fi

############################################
# FILE PERMISSIONS & SUID CHECK
############################################
log "[app_security] Checking for SUID/SGID binaries."

if confirm_long; then
    find / -perm /6000 -type f 2>/dev/null > ./suid_sgid_files.log
    log_info "SUID/SGID files logged to ./suid_sgid_files.log"
else
    log_info "SUID/SGID scan skipped."
fi

############################################
# CRON & TIMERS REVIEW
############################################
log "[app_security] Reviewing scheduled tasks."

if confirm_long; then
    crontab -l 2>/dev/null > ./user_cron.log || true
    ls -l /etc/cron.* > ./system_cron_dirs.log 2>/dev/null

    systemctl list-timers --all > ./systemd_timers.log

    log_info "Cron jobs and timers logged for review."
else
    log_info "Cron/timer review skipped."
fi

############################################
# SUMMARY
############################################
log "[app_security] Hardening review complete."
log "[app_security] No services were restarted or disabled automatically."
log "[app_security] All changes are review-based unless manually applied."
