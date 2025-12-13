#!/bin/bash
# user_audit.sh
# - Audit user accounts, groups, sudoers, failed login attempts, password aging
# - Warn about weak/empty password shells, locked accounts etc.

source ./os_misc.sh
log "[user_audit] Starting user and auth audit."

# Output existing users & groups
getent passwd | awk -F: '{print $1":"$3":"$6}' > ./user_audit_passwd.tsv
getent group > ./user_audit_groups.txt

# Find accounts with UID 0 except root
awk -F: '($3 == 0) {print $1}' /etc/passwd | grep -v "^root$" > ./user_audit_uid0_nonroot.log || true

# Accounts with no password (shadow field empty or '!'?) - list
awk -F: '($2 == "") {print $1}' /etc/shadow > ./user_audit_nopasswd.log 2>/dev/null || true
grep -E '^[^:]+:!:|^[^:]+:!!:' /etc/shadow > ./user_audit_locked_accounts.log || true

# Sudoers checks
if [[ -f /etc/sudoers ]]; then
    cp /etc/sudoers ./backups/sudoers.bak 2>/dev/null || true
    visudo -c 2>&1 | tee ./user_audit_visudo_check.log || true
    awk -F: '/sudo/{print $4}' /etc/group > ./user_audit_sudo_members.txt || true
fi

# Password aging
chage -l root > ./user_audit_root_chage.txt 2>/dev/null || true
awk -F: '{print $1":"$5":"$6":"$7}' /etc/shadow > ./user_audit_shadow_info.txt 2>/dev/null || true

# Failed login tracking (auth.log)
grep "Failed password" /var/log/auth.log > ./user_audit_failed_passwords.log 2>/dev/null || true
grep "Invalid user" /var/log/auth.log > ./user_audit_invalid_user.log 2>/dev/null || true

log "[user_audit] Completed. Review user audit logs."
