#!/bin/bash
# app_security.sh
# - Install security packages & run rootkit checks
# - SSH hardening helper
# - Small helper to set IDS interface (same interactive block as defense.sh)
# - NOTE: this script will source os_misc.sh and may prompt for interface if NET_IFACE not provided

source ./os_misc.sh
log "[app_security] Installing application security packages and hardening config."

# install a minimal set (kept conservative)
PACKAGES=(rkhunter chkrootkit clamav clamav-daemon libpam-google-authenticator)
apt-get update -y
apt-get install -y "${PACKAGES[@]}" || log "[app_security] Some packages failed to install; check apt logs."

# Run rootkit checks (non-fatal)
log "[app_security] Running chkrootkit (if available)..."
chkrootkit || true

log "[app_security] Running rkhunter update/check (if available)..."
cat > /etc/default/rkhunter << EOF
CRON_DAILY_RUN="yes"
CRON_DB_UPDATE="yes"
APT_AUTOGEN="yes"
REPORT_EMAIL="root"
EOF
rkhunter --update || true
rkhunter --check || true
rkhunter --propupd || true

# SSH hardening (same as previously)
if command -v sshd &> /dev/null; then
    log "[app_security] Hardening SSH configuration..."
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
    systemctl restart ssh || true
    log "[app_security] SSH hardening applied (verify manually)."
fi

# === NEW: optional small helper to set interface for IDS tools if desired ===
# This mirrors the defense.sh helper so user can run it from either script.
if [[ -z "${NET_IFACE:-}" ]]; then
    read -r -p "Do you want to set the network interface for IDS services now? (y/N): " _ans_iface
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
    log "[app_security] NET_IFACE set to $NET_IFACE. Attempting to update suricata/ntopng configs (if present)."

    # Suricata
    if [[ -f /etc/suricata/suricata.yaml ]]; then
        mkdir -p ./backups/suricata || true
        cp /etc/suricata/suricata.yaml ./backups/suricata/suricata.yaml.bak
        if grep -qE '^\s*interface:' /etc/suricata/suricata.yaml; then
            sed -i "s|^\(\s*interface:\s*\).*|\1${NET_IFACE}|" /etc/suricata/suricata.yaml
        else
            echo "# Note: Please ensure Suricata is set to monitor interface: $NET_IFACE" >> /etc/suricata/suricata.yaml
        fi
        log "[app_security] Suricata config updated (verify)."
    fi

    # ntopng
    if [[ -f /etc/ntopng/ntopng.conf ]]; then
        mkdir -p ./backups/ntopng || true
        cp /etc/ntopng/ntopng.conf ./backups/ntopng/ntopng.conf.bak
        if grep -qE '^\s*-i\s+' /etc/ntopng/ntopng.conf; then
            sed -i "s|^\(\s*-i\s*\).*| -i ${NET_IFACE}|" /etc/ntopng/ntopng.conf
        elif grep -qE '^\s*interface=' /etc/ntopng/ntopng.conf; then
            sed -i "s|^\(\s*interface=\).*|\1${NET_IFACE}|" /etc/ntopng/ntopng.conf
        else
            echo "-i ${NET_IFACE}" >> /etc/ntopng/ntopng.conf
        fi
        log "[app_security] ntopng config updated (verify)."
    fi

    read -r -p "Restart suricata/ntopng now? (y/N): " _r2
    if [[ "${_r2,,}" == "y" ]]; then
        systemctl restart suricata || true
        systemctl restart ntopng || true
        log "[app_security] restarted suricata/ntopng (if available)."
    fi
fi

log "[app_security] Done."
