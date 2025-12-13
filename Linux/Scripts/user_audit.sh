#!/bin/bash
# user_audit.sh
# - Audit user accounts, groups, sudoers, failed login attempts, password aging
# - Read-only: NO enforcement or config modification

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/os_misc.sh"

log "[user_audit] Starting user and auth audit."

mkdir -p "$SCRIPT_DIR/backups/user_audit"

# Existing users & groups
getent passwd | awk -F: '{print $1":"$3":"$6}' > ./user_audit_passwd.tsv
getent group > ./user_audit_groups.txt

# UID 0 accounts (non-root)
awk -F: '($3 == 0) {print $1}' /etc/passwd | grep -v "^root$" > ./user_audit_uid0_nonroot.log || true

# Password status
awk -F: '($2 == "") {print $1}' /etc/shadow > ./user_audit_nopasswd.log 2>/dev/null || true
grep -E '^[^:]+:!:|^[^:]+:!!:' /etc/shadow > ./user_audit_locked_accounts.log || true

# Sudoers validation & membership (NO backups here)
if [[ -f /etc/sudoers ]]; then
    visudo -c 2>&1 | tee ./user_audit_visudo_check.log || true
    getent group sudo | awk -F: '{print $4}' | tr ',' '\n' > ./user_audit_sudo_members.txt || true
fi

# Password aging
chage -l root > ./user_audit_root_chage.txt 2>/dev/null || true
awk -F: '{print $1":"$5":"$6":"$7}' /etc/shadow > ./user_audit_shadow_info.txt 2>/dev/null || true

# Failed login attempts
grep "Failed password" /var/log/auth.log > ./user_audit_failed_passwords.log 2>/dev/null || true
grep "Invalid user" /var/log/auth.log > ./user_audit_invalid_user.log 2>/dev/null || true

log "[user_audit] Completed. Review user audit logs."
