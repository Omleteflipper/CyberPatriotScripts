#!/bin/bash
# defense.sh
# - Firewall (nftables + UFW helpers)
# - IDS/ntopng/suricata helper (interactive/network interface)
# - Malware detection: ClamAV, chkrootkit, rkhunter, AIDE
# - knockd starter
# - Non-destructive; warns before risky operations; keeps backups

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/os_misc.sh"

log "[defense] Starting defense & malware tasks."

# --- BACKUPS ---
mkdir -p ./backups/firewall ./backups/ids ./backups/clamav ./backups/suricata ./backups/ntopng || true

# --- SECURITY PACKAGES ---
SEC_PACKAGES=(rkhunter chkrootkit clamav clamav-daemon aide knockd ufw nftables)
install_packages "${SEC_PACKAGES[@]}" || log "[defense] Some packages failed to install; check apt logs."

# --- FIREWALL ---
if command -v nft &> /dev/null; then
    log "[defense] Backing up existing nftables config..."
    nft list ruleset > ./backups/firewall/nftables.rules 2>/dev/null || true
fi
if command -v iptables &> /dev/null; then
    iptables-save > ./backups/firewall/iptables.rules 2>/dev/null || true
    ip6tables-save > ./backups/firewall/ip6tables.rules 2>/dev/null || true
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

if command -v ufw &> /dev/null; then
    log "[defense] Preparing UFW defaults (not enabling automatically)."
    ufw default deny incoming || true
    ufw default allow outgoing || true
    ufw allow ssh || true
    ufw allow 80/tcp || true
    ufw allow 443/tcp || true
fi

# --- KNOCKD ---
if command -v knockd &> /dev/null; then
    log "[defense] Setting up knockd if not existing."
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
    fi
fi

# --- IDS INTERFACE HELPER (Suricata/ntopng) ---
if [[ -z "${NET_IFACE:-}" ]]; then
    echo
    echo "=== Network interface helper ==="
    ip addr show
    read -r -p "Enter your active network interface (leave blank to skip): " NET_IFACE_INPUT
    NET_IFACE="${NET_IFACE_INPUT:-}"
else
    log "[defense] NET_IFACE provided via environment: $NET_IFACE"
fi

if [[ -n "${NET_IFACE:-}" ]]; then
    log "[defense] Using interface: $NET_IFACE"

    # Suricata
    if [[ -f /etc/suricata/suricata.yaml ]]; then
        cp /etc/suricata/suricata.yaml ./backups/suricata/suricata.yaml.bak 2>/dev/null || true
        if grep -qE '^\s*interface:' /etc/suricata/suricata.yaml; then
            sed -i "s|^\(\s*interface:\s*\).*|\1${NET_IFACE}|" /etc/suricata/suricata.yaml
        else
            echo "# Note: Please ensure Suricata monitors: ${NET_IFACE}" >> /etc/suricata/suricata.yaml
        fi
    fi

    # ntopng
    if [[ -f /etc/ntopng/ntopng.conf ]]; then
        cp /etc/ntopng/ntopng.conf ./backups/ntopng/ntopng.conf.bak 2>/dev/null || true
        if grep -qE '^\s*-i\s+' /etc/ntopng/ntopng.conf; then
            sed -i "s|^\(\s*-i\s*\).*| -i ${NET_IFACE}|" /etc/ntopng/ntopng.conf
        elif grep -qE '^\s*interface=' /etc/ntopng/ntopng.conf; then
            sed -i "s|^\(\s*interface=\).*|\1${NET_IFACE}|" /etc/ntopng/ntopng.conf
        else
            echo "-i ${NET_IFACE}" >> /etc/ntopng/ntopng.conf
        fi
    fi

    read -r -p "Restart Suricata/ntopng now? (y/N): " _r
    if [[ "${_r,,}" == "y" ]]; then
        systemctl restart suricata || true
        systemctl restart ntopng || true
    fi
fi

# --- MALWARE DETECTION ---
if command -v chkrootkit &> /dev/null; then
    log "[defense] Running chkrootkit..."
    chkrootkit || true
fi

if command -v rkhunter &> /dev/null; then
    log "[defense] Updating & checking rkhunter..."
    rkhunter --update || true
    rkhunter --check || true
    rkhunter --propupd || true
    rkhunter -c --enable all --disable none || true
fi

# ClamAV
if command -v freshclam &> /dev/null; then
    log "[defense] Updating ClamAV DB..."
    freshclam || true
fi

# AIDE
log "[defense] Configuring AIDE..."
cat > /etc/aide/aide.conf <<EOF
database = /var/lib/aide/aide.db
database_out = /var/lib/aide/aide.db.new
gzip_dbout = yes
exclude = /tmp
exclude = /var/tmp
exclude = /var/log
exclude = /var/run
exclude = /var/cache
dir = /etc
dir = /bin
dir = /sbin
dir = /usr
dir = /lib
dir = /lib64
dir = /root
dir = /home
dir = /opt
dir = /var/spool
dir = /var/lib
dir = /var/opt
file = /etc/passwd
file = /etc/shadow
file = /etc/group
file = /etc/gshadow
file = /etc/hostname
file = /etc/hosts
file = /etc/sudoers
EOF

log "[defense] Initializing AIDE DB..."
aideinit || true
if [[ -f /var/lib/aide/aide.db.new ]]; then
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null || true
fi
aide --check || true

log "[defense] Defense & malware tasks completed. Review backups in ./backups."
