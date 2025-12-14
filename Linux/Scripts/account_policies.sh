#!/bin/bash
# account_policies.sh
# - System-wide authentication & password policies
# - Enforced user/admin authorization (interactive)
# - Root & boot protection (optional, explicit)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/os_misc.sh"
NEW_PASSWORD="CyberPatr!0t"

log "[account_policies] Starting account policy tasks."

# --- BACKUPS ---
mkdir -p "$SCRIPT_DIR/backups/account_policies"
cp /etc/login.defs "$SCRIPT_DIR/backups/account_policies/login.defs.bak" 2>/dev/null || true
cp /etc/pam.d/common-auth "$SCRIPT_DIR/backups/account_policies/common-auth.bak" 2>/dev/null || true
cp /etc/pam.d/common-password "$SCRIPT_DIR/backups/account_policies/common-password.bak" 2>/dev/null || true

# =========================================================
# SYSTEM-WIDE PASSWORD & AUTH POLICIES
# =========================================================

log "[account_policies] Enforcing password lifetime values..."
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 30/;
        s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS 10/;
        s/^PASS_WARN_AGE.*/PASS_WARN_AGE 7/' /etc/login.defs

# PAM faillock
if ! grep -q "pam_faillock.so" /etc/pam.d/common-auth; then
    log "[account_policies] Adding pam_faillock"
    {
        echo "auth required pam_faillock.so preauth deny=5 unlock_time=3600"
        echo "auth required pam_faillock.so authfail deny=5 unlock_time=3600"
    } >> /etc/pam.d/common-auth
fi

# Password complexity
log "[account_policies] Hardening password complexity"
sed -i 's/\(pam_unix\.so.*\)$/\1 remember=5 minlen=12/' /etc/pam.d/common-password || true
sed -i 's/\(pam_cracklib\.so.*\)$/\1 minlen=12 difok=8 minclass=4 dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1 retry=5/' /etc/pam.d/common-password || true

# Strong hashing
grep -q "^ENCRYPT_METHOD SHA512" /etc/login.defs || echo "ENCRYPT_METHOD SHA512" >> /etc/login.defs
grep -q "^SHA_CRYPT_MIN_ROUNDS" /etc/login.defs || echo "SHA_CRYPT_MIN_ROUNDS 12000" >> /etc/login.defs
grep -q "^SHA_CRYPT_MAX_ROUNDS" /etc/login.defs || echo "SHA_CRYPT_MAX_ROUNDS 15000" >> /etc/login.defs

# =========================================================
# USER & ADMIN AUTHORIZATION ENFORCEMENT
# =========================================================

USERS_FILE="$SCRIPT_DIR/users.txt"
ADMINS_FILE="$SCRIPT_DIR/admins.txt"

USERS=()
ADMINS=()
[[ -f "$USERS_FILE" ]] && mapfile -t USERS < "$USERS_FILE"
[[ -f "$ADMINS_FILE" ]] && mapfile -t ADMINS < "$ADMINS_FILE"

existing_users=$(cut -d: -f1 /etc/passwd)

# Remove unauthorized users
for u in $existing_users; do
    uid=$(id -u "$u" 2>/dev/null || echo "")
    if [[ -n "$uid" && "$uid" -ge 1000 && ! " ${USERS[*]} ${ADMINS[*]} " =~ " $u " ]]; then
        read -r -p "Unauthorized user '$u'. Remove? (y/N): " ans
        [[ "$ans" =~ ^[Yy] ]] && userdel -r "$u" && log "[account_policies] Removed user: $u"
    fi
done

# Enforce sudo membership
for a in $(getent group sudo | cut -d: -f4 | tr ',' ' '); do
    if [[ ! " ${ADMINS[*]} " =~ " $a " ]]; then
        read -r -p "Unauthorized sudo user '$a'. Remove from sudo? (y/N): " ans
        [[ "$ans" =~ ^[Yy] ]] && deluser "$a" sudo && log "[account_policies] Removed sudo: $a"
    fi
done

# Create missing users/admins
for u in "${USERS[@]}"; do
    id "$u" &>/dev/null || { read -r -p "Create user '$u'? (y/N): " ans; [[ "$ans" =~ ^[Yy] ]] && useradd -m "$u"; }
done
for a in "${ADMINS[@]}"; do
    id "$a" &>/dev/null || { read -r -p "Create admin '$a'? (y/N): " ans; [[ "$ans" =~ ^[Yy] ]] && useradd -m "$a" && usermod -aG sudo "$a"; }
done

# change passwords for authorized users
read -r -p "Change all user's passwords? This can lock you out! (y/N): " ans
if [[ "$ans" =~ ^[Yy] ]]; then
        for u in "${USERS[@]}" "${ADMINS[@]}"; do
            log "[account_policies] Setting password for user: $u"
            echo "$u:$NEW_PASSWORD" | chpasswd
            log "[account_policies] Password updated for user: $u"
        done
fi

# =========================================================
# ROOT & BOOT PROTECTION
# =========================================================

log "[account_policies] Locking root account"
echo "root:$NEW_PASSWORD" | chpasswd || true
passwd -l root || true
usermod -s /usr/sbin/nologin root || true

# GRUB protection (explicit opt-in)
if command -v grub-mkpasswd-pbkdf2 &> /dev/null; then
    read -r -p "Configure GRUB password? This can lock you out! (y/N): " ans
    if [[ "$ans" =~ ^[Yy] ]]; then
        HASH=$(echo -e "$NEW_PASSWORD\n$NEW_PASSWORD" | grub-mkpasswd-pbkdf2 | grep -o "grub.pbkdf2.sha512.*")
        [[ -n "$HASH" ]] && echo -e "set superusers=\"root\"\npassword_pbkdf2 root $HASH" >> /etc/grub.d/40_custom && update-grub
    fi
fi

log "[account_policies] Completed account policy tasks."
