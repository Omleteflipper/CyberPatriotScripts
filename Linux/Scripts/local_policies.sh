#!/bin/bash
# local_policies.sh
# - Sysctl hardening, auditd, mount options, GRUB tweaks (safe)
# - This file now appends kernel args safely, asks for confirmation before update-grub,
#   and keeps backups of /etc/default/grub and /etc/grub.d/40_custom.
# - NOTE: GRUB edits can make systems unbootable. This script requires confirmation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/os_misc.sh"

log "[local_policies] Applying local policy and sysctl hardening."

# (preserve auditd + sysctl blocks from earlier)
if command -v auditctl &> /dev/null; then
    mkdir -p ./backups/auditd || true
    cp /etc/audit/audit.rules ./backups/auditd/audit.rules.bak 2>/dev/null || true
    cat > /etc/audit/rules.d/cyberpatriot.rules <<'EOF'
# CyberPatriot baseline audit rules (minimal)
-D
-b 8192
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers
-w /var/log/auth.log -p wa -k authlog
-w /var/log/syslog -p wa -k syslog
EOF
    systemctl restart auditd || true
fi

# sysctl
SYSCTL_CONF="/etc/sysctl.d/99-cyberpatriot.conf"
cat > "$SYSCTL_CONF" <<'EOF'
# Kernel hardening for competition baseline
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
kernel.randomize_va_space = 2
fs.suid_dumpable = 0
EOF
sysctl --system || log "[local_policies] sysctl apply returned non-zero (review)."

# Mount options note (non-destructive)
log "[local_policies] /tmp & /var/tmp mount options left unchanged (recommend manual remount with noexec,nosuid if appropriate)."

# ========== SAFER GRUB KERNEL ARG APPEND ==========
GRUB_FILE="/etc/default/grub"
GRUB_CUSTOM="/etc/grub.d/40_custom"
if [[ -f "$GRUB_FILE" ]]; then
    mkdir -p ./backups/grub || true
    cp "$GRUB_FILE" "./backups/grub/default_grub.bak" 2>/dev/null || true
    cp "$GRUB_CUSTOM" "./backups/grub/40_custom.bak" 2>/dev/null || true

    echo
    echo "WARNING: You are about to append kernel hardening options to $GRUB_FILE."
    echo "This may render the system unbootable if misapplied. A backup has been saved to ./backups/grub/."
    read -r -p "Proceed to append 'mitigations=auto' to GRUB_CMDLINE_LINUX_DEFAULT and run update-grub? (y/N): " CONFIRM_GRUB

    if [[ "${CONFIRM_GRUB,,}" == "y" ]]; then
        # Append mitigations=auto if it's not already included
        if grep -q 'mitigations=auto' "$GRUB_FILE"; then
            log "[local_policies] mitigations=auto already present in $GRUB_FILE (skipping append)."
        else
            # Insert before the closing quote in GRUB_CMDLINE_LINUX_DEFAULT, preserving existing args
            sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/{
                s/^\(GRUB_CMDLINE_LINUX_DEFAULT="\)\(.*\)"/\1\2 mitigations=auto"/
            }' "$GRUB_FILE"
            log "[local_policies] Appended 'mitigations=auto' to GRUB_CMDLINE_LINUX_DEFAULT."
        fi

        # Optionally run update-grub (ask again)
        read -r -p "Run update-grub now? (y/N): " CONFIRM_UG
        if [[ "${CONFIRM_UG,,}" == "y" ]]; then
            update-grub || log "[local_policies] update-grub returned non-zero (check)."
            log "[local_policies] update-grub executed (verify grub.cfg/backups)."
        else
            log "[local_policies] Skipped running update-grub; remember to run it manually after review."
        fi
    else
        log "[local_policies] Skipped GRUB modification per user choice."
    fi
else
    log "[local_policies] $GRUB_FILE not found; skipping GRUB hardening."
fi

log "[local_policies] Completed local policy tasks."
