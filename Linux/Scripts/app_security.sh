#!/bin/bash
# app_security.sh
# - Install security packages (uses install_packages wrapper from os_misc)
# - Configure rkhunter defaults & run update/check/propupd
# - Run chkrootkit (if present)
# - SSH hardening helper (sets common robust options)
# - Optional interactive helper to set IDS interface (Suricata/ntopng) safely with backups
#
# NOTE: This script attempts to be additive and non-destructive. It creates backups before changes.

set -euo pipefail
source ./os_misc.sh
log "[app_security] Starting application security setup."

# CURATED SECURITY PACKAGE LIST
SEC_PACKAGES=(rkhunter chkrootkit clamav clamav-daemon libpam-google-authenticator apparmor apparmor-utils fail2ban net-tools debsums)
# Use install_packages wrapper (will enable universe on Ubuntu-family if needed)
install_packages "${SEC_PACKAGES[@]}" || log "[app_security] Some packages failed to install; check apt logs."

# rkhunter default config (safe, mirrors original)
log "[app_security] Writing /etc/default/rkhunter (backup preserved)."
cp /etc/default/rkhunter /etc/default/rkhunter.bak 2>/dev/null || true
cat > /etc/default/rkhunter << EOF
CRON_DAILY_RUN="yes"
CRON_DB_UPDATE="yes"
APT_AUTOGEN="yes"
REPORT_EMAIL="root"
EOF

# Run rkhunter checks (best-effort)
if command -v rkhunter &> /dev/null; then
    log "[app_security] Updating rkhunter DB and running checks (may be slow)."
    rkhunter --update || true
    rkhunter --check || true
    rkhunter --propupd || true
fi

# Run chkrootkit if available
if command -v chkrootkit &> /dev/null; then
    log "[app_security] Running chkrootkit..."
    chkrootkit || true
fi

# Clam AV db update (if present)
if command -v freshclam &> /dev/null; then
    log "[app_security] Updating ClamAV DB..."
    freshclam || true
fi

# SSH hardening - create a backup and set safe defaults
if command -v sshd &> /dev/null; then
    log "[app_security] Hardening SSH config (backing up current file)."
    sshd_config="/etc/ssh/sshd_config"
    cp "$sshd_config" "${sshd_config}.bak" 2>/dev/null || true

    set_sshd_setting() {
        local setting="$1"
        local value="$2"
        if grep -qE "^[#]*\s*${setting}" "$sshd_config"; then
            sed -i "s|^[#]*\s*${setting}.*|${setting} ${value}|" "$sshd_config"
        else
            echo "${setting} ${value}" >> "$sshd_config"
        fi
    }

    set_sshd_setting "PermitRootLogin" "no"
    set_sshd_setting "PasswordAuthentication" "no"
    set_sshd_setting "ChallengeResponseAuthentication" "no"
    set_sshd_setting "UsePAM" "yes"
    set_sshd_setting "HostbasedAuthentication" "no"
    set_sshd_setting "Protocol" "2"
    set_sshd_setting "LogLevel" "VERBOSE"
    set_sshd_setting "X11Forwarding" "no"
    set_sshd_setting "MaxAuthTries" "3"
    set_sshd_setting "PermitEmptyPasswords" "no"

    # Restart sshd (best-effort)
    systemctl restart ssh || log "[app_security] ssh restart returned non-zero; verify sshd_config before reconnecting."
    log "[app_security] SSH hardening applied; verify manually."
fi

# === Optional: Interactive helper to set IDS interface (Suricata/ntopng)
if [[ -z "${NET_IFACE:-}" ]]; then
    read -r -p "Do you want to configure an interface for Suricata/ntopng now? (y/N): " _ans_iface
    if [[ "${_ans_iface,,}" == "y" ]]; then
        echo
        echo "Run 'ip addr show' to list interfaces and find the one with your IP."
        ip addr show
        echo
        read -r -p "Enter your active network interface (e.g., ens3, eth0, enp0s3): " NET_IFACE_INPUT
        NET_IFACE="${NET_IFACE_INPUT:-}"
    fi
fi

if [[ -n "${NET_IFACE:-}" ]]; then
    log "[app_security] NET_IFACE set to $NET_IFACE; will attempt safe edits with backups."

    # Backup dir
    mkdir -p ./backups/ids || true

    # Suricata: try to update simple `interface:` lines, otherwise add a comment/notice (YAML is fragile with sed)
    if [[ -f /etc/suricata/suricata.yaml ]]; then
        cp /etc/suricata/suricata.yaml ./backups/ids/suricata.yaml.bak 2>/dev/null || true
        if grep -qE '^\s*interface:' /etc/suricata/suricata.yaml; then
            sed -i "s|^\(\s*interface:\s*\).*|\1${NET_IFACE}|" /etc/suricata/suricata.yaml
            log "[app_security] Updated simple 'interface:' line in suricata.yaml (verify more complex YAML sections manually)."
        else
            echo "# NOTE: Please set Suricata to monitor interface: ${NET_IFACE}" >> /etc/suricata/suricata.yaml
            log "[app_security] Appended note to suricata.yaml instructing interface change (manual review recommended)."
        fi
    else
        log "[app_security] /etc/suricata/suricata.yaml not found; skipping Suricata config."
    fi

    # ntopng: try to set -i or interface= lines
    if [[ -f /etc/ntopng/ntopng.conf ]]; then
        cp /etc/ntopng/ntopng.conf ./backups/ids/ntopng.conf.bak 2>/dev/null || true
        if grep -qE '^\s*-i\s+' /etc/ntopng/ntopng.conf; then
            sed -i "s|^\(\s*-i\s*\).*| -i ${NET_IFACE}|" /etc/ntopng/ntopng.conf
        elif grep -qE '^\s*interface=' /etc/ntopng/ntopng.conf; then
            sed -i "s|^\(\s*interface=\).*|\1${NET_IFACE}|" /etc/ntopng/ntopng.conf
        else
            echo "-i ${NET_IFACE}" >> /etc/ntopng/ntopng.conf
        fi
        log "[app_security] ntopng config updated (verify)."
    else
        log "[app_security] /etc/ntopng/ntopng.conf not found; skipping ntopng config."
    fi

    # Ask user whether to restart services
    read -r -p "Restart suricata/ntopng services now (if present)? (y/N): " _r2
    if [[ "${_r2,,}" == "y" ]]; then
        systemctl restart suricata || true
        systemctl restart ntopng || true
        log "[app_security] Attempted to restart suricata/ntopng (if available)."
    else
        log "[app_security] Skipped restarting IDS services; remember to restart after manual verification."
    fi
fi

log "[app_security] Completed application security tasks."
