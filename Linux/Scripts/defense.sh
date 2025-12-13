#!/bin/bash
# defense.sh
# - Firewall (nftables + UFW helpers)
# - IDS/ntopng/suricata helper (prompts for interface & updates configs)
# - ClamAV, knockd starter
# - NOTE: this file now includes an interactive helper to set your network interface
# - To run non-interactively, run and provide the interface via NET_IFACE env var:
#      NET_IFACE=ens3 sudo ./defense.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/os_misc.sh"

log "[defense] Starting defense module."

# --- existing logic preserved (firewall backups, nft dry-run, ufw helper, clamav, knockd) ---
mkdir -p ./backups/firewall || true

if command -v nft &> /dev/null; then
    log "[defense] Backing up existing nftables config..."
    nft list ruleset > ./backups/firewall/nftables.rules 2>/dev/null || true
fi
if command -v iptables &> /dev/null; then
    log "[defense] Backing up existing iptables rules..."
    iptables-save > ./backups/firewall/iptables.rules 2>/dev/null || true
    if command -v ip6tables &> /dev/null; then
        ip6tables-save > ./backups/firewall/ip6tables.rules 2>/dev/null || true
    fi
fi

NFT_RULES_FILE="./nft_ruleset.cpt"
cat > "$NFT_RULES_FILE" <<'EOF'
# nftables example minimal hardened ruleset (dry-run, review before apply)
table inet filter {
    chain input {
        type filter hook input priority 0;
        policy drop;
        ct state established,related accept
        iif lo accept
        tcp dport { 22, 80, 443 } ct state new accept
        icmp type echo-request accept
    }
    chain forward { policy drop; }
    chain output { policy accept; }
}
EOF

log "[defense] Generated example nftables rules at $NFT_RULES_FILE (review)."

# UFW helper (prepare but not enabling forcefully)
if command -v ufw &> /dev/null; then
    log "[defense] Preparing UFW conservative defaults (not enabling automatically)."
    ufw default deny incoming || true
    ufw default allow outgoing || true
    ufw allow ssh || true
    ufw allow 80/tcp || true
    ufw allow 443/tcp || true
    log "[defense] UFW prepared. Run 'ufw status' and 'ufw enable' after review."
fi

# ClamAV
if command -v freshclam &> /dev/null; then
    log "[defense] Updating ClamAV DB and ensuring service is enabled."
    freshclam || true
    systemctl enable clamav-freshclam || true
    systemctl start clamav-freshclam || true
fi

# knockd
if command -v knockd &> /dev/null; then
    log "[defense] Ensuring basic knockd config exists and service is enabled."
    if [[ ! -f /etc/knockd.conf ]]; then
        cat > /etc/knockd.conf <<'EOF'
[options]
    UseSyslog

[openSSH]
    sequence    = 7000,8000,9000
    seq_timeout = 5
    command     = /sbin/iptables -A INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
    tcpflags    = syn

[closeSSH]
    sequence    = 9000,8000,7000
    seq_timeout = 5
    command     = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
EOF
        systemctl enable knockd || true
        systemctl start knockd || true
        log "[defense] knockd enabled with example config. Adjust to taste."
    else
        log "[defense] knockd.conf exists (skipping creation)."
    fi
fi

# === NEW: Interactive helper to choose network interface and update Suricata/ntopng configs ===
# This provides instructions, runs `ip addr`, prompts for the interface, backs up files and updates them.
if [[ -z "${NET_IFACE:-}" ]]; then
    echo
    echo "=== Network interface helper ==="
    echo "This helper will show your current interfaces and let you choose one to apply to IDS tools."
    echo "Run 'ip addr show' below and note the interface name that has the VM's IP (e.g., ens3, enp0s3, eth0)."
    echo
    ip addr show
    echo
    read -r -p "Enter your active network interface (leave blank to skip interface auto-config): " NET_IFACE_INPUT
    NET_IFACE="${NET_IFACE_INPUT:-$NET_IFACE}"
else
    log "[defense] NET_IFACE provided via environment: $NET_IFACE"
fi

if [[ -n "${NET_IFACE:-}" ]]; then
    log "[defense] Using interface: $NET_IFACE"

    # Update Suricata config if present
    if [[ -f /etc/suricata/suricata.yaml ]]; then
        mkdir -p ./backups/suricata || true
        cp /etc/suricata/suricata.yaml ./backups/suricata/suricata.yaml.bak
        # Try to replace top-level 'interface:' occurrences
        if grep -qE '^\s*interface:' /etc/suricata/suricata.yaml; then
            sed -i "s|^\(\s*interface:\s*\).*|\1${NET_IFACE}|" /etc/suricata/suricata.yaml
        else
            # If no simple interface entry, add a notice at top (manual review)
            echo "# Note: Please ensure Suricata is set to monitor interface: $NET_IFACE" >> /etc/suricata/suricata.yaml
        fi
        log "[defense] Suricata config backed up and attempted to set interface to $NET_IFACE (verify manually)."
    else
        log "[defense] Suricata config not found at /etc/suricata/suricata.yaml (skipping)."
    fi

    # Update ntopng config if present
    if [[ -f /etc/ntopng/ntopng.conf ]]; then
        mkdir -p ./backups/ntopng || true
        cp /etc/ntopng/ntopng.conf ./backups/ntopng/ntopng.conf.bak
        # Replace lines starting with -i or interface= or --interface
        if grep -qE '^\s*-i\s+' /etc/ntopng/ntopng.conf; then
            sed -i "s|^\(\s*-i\s*\).*| -i ${NET_IFACE}|" /etc/ntopng/ntopng.conf
        elif grep -qE '^\s*interface=' /etc/ntopng/ntopng.conf; then
            sed -i "s|^\(\s*interface=\).*|\1${NET_IFACE}|" /etc/ntopng/ntopng.conf
        else
            # add a -i line if none present
            echo "-i ${NET_IFACE}" >> /etc/ntopng/ntopng.conf
        fi
        log "[defense] ntopng config backed up and attempted to set interface to $NET_IFACE (verify manually)."
    else
        log "[defense] ntopng config not found at /etc/ntopng/ntopng.conf (skipping)."
    fi

    # Optionally restart services if desired (prompt)
    read -r -p "Restart Suricata/ntopng services now to apply interface change? (y/N): " _r
    if [[ "${_r,,}" == "y" ]]; then
        systemctl restart suricata || true
        systemctl restart ntopng || true
        log "[defense] Restarted Suricata/ntopng (if present)."
    else
        log "[defense] Skipped restarting IDS services; remember to restart after manual review."
    fi
else
    log "[defense] No interface selected; skipped Suricata/ntopng auto-config."
fi

# End of defense tasks
log "[defense] Defense tasks completed. Review backups & configs in ./backups."
