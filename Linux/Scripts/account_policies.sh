#!/bin/bash
# account_policies.sh
# - Password policy, PAM faillock, pwquality tweaks
# - Create users/admins lists interactively (users.txt, admins.txt) if missing
# - Set default password for created users (NEW_PASSWORD variable)
# - Configure GRUB password with explicit confirmation & backups (safe)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/os_misc.sh"

log "[account_policies] Starting account policy tasks."

# Backups
mkdir -p ./backups/account_policies || true
cp /etc/login.defs ./backups/account_policies/login.defs.bak 2>/dev/null || true
cp /etc/pam.d/common-auth ./backups/account_policies/common-auth.bak 2>/dev/null || true
cp /etc/pam.d/common-password ./backups/account_policies/common-password.bak 2>/dev/null || true

# Password policy in login.defs
log "[account_policies] Enforcing password lifetime values..."
sed -i 's/^PASS_MAX_DAYS.*$/PASS_MAX_DAYS 30/; s/^PASS_MIN_DAYS.*$/PASS_MIN_DAYS 10/; s/^PASS_WARN_AGE.*$/PASS_WARN_AGE 7/' /etc/login.defs

# PAM faillock
if ! grep -q "pam_faillock.so" /etc/pam.d/common-auth; then
    log "[account_policies] Adding pam_faillock to common-auth"
    echo "auth required pam_faillock.so preauth deny=5 unlock_time=3600" >> /etc/pam.d/common-auth
    echo "auth required pam_faillock.so authfail deny=5 unlock_time=3600" >> /etc/pam.d/common-auth
fi

# pwquality/pam_cracklib
log "[account_policies] Hardening common-password options"
sed -i 's/\(pam_unix\.so.*\)$/\1 remember=5 minlen=12/' /etc/pam.d/common-password || true
sed -i 's/\(pam_cracklib\.so.*\)$/\1 maxclassrepeat=5 maxsequence=5 minclass=4 dcredit=-1 ocredit=-1 lcredit=-1 ucredit=-1 minlen=12 difok=8 retry=5/' /etc/pam.d/common-password || true

# Ensure ENCRYPT_METHOD SHA512
if ! grep -q "^ENCRYPT_METHOD SHA512" /etc/login.defs; then
    sed -i '/^ENCRYPT_METHOD/c\ENCRYPT_METHOD SHA512' /etc/login.defs || echo "ENCRYPT_METHOD SHA512" >> /etc/login.defs
fi
grep -q "^SHA_CRYPT_MIN_ROUNDS" /etc/login.defs || echo "SHA_CRYPT_MIN_ROUNDS 12000" >> /etc/login.defs
grep -q "^SHA_CRYPT_MAX_ROUNDS" /etc/login.defs || echo "SHA_CRYPT_MAX_ROUNDS 15000" >> /etc/login.defs

# --- Users / Admins files handling ---
# If users.txt or admins.txt missing, prompt interactively to create them.
if [[ ! -f ./users.txt ]]; then
    echo
    echo "users.txt not found. You can create it now interactively (one username per line),"
    echo "or press Enter to skip creating users.txt."
    read -r -p "Create users.txt now? (y/N): " _create_users
    if [[ "${_create_users,,}" == "y" ]]; then
        echo "Enter usernames (empty line to finish):"
        > ./users.txt
        while true; do
            read -r username
            [[ -z "$username" ]] && break
            echo "$username" >> ./users.txt
        done
        log "[account_policies] Created users.txt with entries:"
        cat ./users.txt | tee ./backups/account_policies/users_created.log
    else
        log "[account_policies] Skipped interactive users.txt creation."
    fi
else
    log "[account_policies] users.txt present; will use it if accounts need creation."
fi

if [[ ! -f ./admins.txt ]]; then
    echo
    echo "admins.txt not found. You can create it now interactively (one admin username per line),"
    echo "or press Enter to skip creating admins.txt."
    read -r -p "Create admins.txt now? (y/N): " _create_admins
    if [[ "${_create_admins,,}" == "y" ]]; then
        echo "Enter admin usernames (empty line to finish):"
        > ./admins.txt
        while true; do
            read -r adminname
            [[ -z "$adminname" ]] && break
            echo "$adminname" >> ./admins.txt
        done
        log "[account_policies] Created admins.txt with entries:"
        cat ./admins.txt | tee ./backups/account_policies/admins_created.log
    else
        log "[account_policies] Skipped interactive admins.txt creation."
    fi
else
    log "[account_policies] admins.txt present; will use it for admin mapping."
fi

# Build arrays from files (if present)
USERS=()
ADMINS=()
if [[ -f ./users.txt ]]; then
    mapfile -t USERS < ./users.txt
fi
if [[ -f ./admins.txt ]]; then
    mapfile -t ADMINS < ./admins.txt
fi

# Create users/admins (non-destructive: only if not present)
existing_users=$(cut -d: -f1 /etc/passwd)
for u in "${USERS[@]}"; do
    if ! grep -qw "$u" <<< "$existing_users"; then
        log "[account_policies] Creating user: $u"
        useradd -m "$u" || log "[account_policies] Failed to add $u"
    fi
done
for a in "${ADMINS[@]}"; do
    if ! grep -qw "$a" <<< "$existing_users"; then
        log "[account_policies] Creating admin: $a"
        useradd -m "$a" || log "[account_policies] Failed to add admin $a"
    fi
    # ensure admin is in sudo group
    usermod -aG sudo "$a" || true
done

# Set a default password for non-system users (CAUTION: change immediately)
NEW_PASSWORD="CyberPatr!0t"
log "[account_policies] Setting default password for non-system users (change immediately)."
for user in $(cut -d: -f1 /etc/passwd); do
    uid=$(id -u "$user" 2>/dev/null || echo "")
    if [[ -n "$uid" && "$uid" -ge 1000 && "$user" != "nobody" ]]; then
        echo "${user}:${NEW_PASSWORD}" | chpasswd || log "[account_policies] Failed to set password for $user"
    fi
done
# also set root password & lock root shell as original recommended
echo "root:${NEW_PASSWORD}" | chpasswd || true
passwd -l root || true
usermod -s /usr/sbin/nologin root || true
usermod -L root || true

# === SAFER GRUB PASSWORD SETUP (requires explicit confirmation) ===
if command -v grub-mkpasswd-pbkdf2 &> /dev/null; then
    echo
    echo "Configuring GRUB superuser password can lock you out of the system if misapplied."
    echo "A backup of /etc/grub.d/40_custom will be stored in ./backups/account_policies/."
    read -r -p "Proceed with GRUB password setup? (y/N): " CONFIRM_GRUBPW

    if [[ "${CONFIRM_GRUBPW,,}" == "y" ]]; then
        mkdir -p ./backups/account_policies || true
        cp /etc/grub.d/40_custom ./backups/account_policies/40_custom.bak 2>/dev/null || true

        HASH=$(echo -e "${NEW_PASSWORD}\n${NEW_PASSWORD}" | grub-mkpasswd-pbkdf2 | grep -o "grub.pbkdf2.sha512.*" || true)
        if [[ -n "$HASH" ]]; then
            cat > /etc/grub.d/40_custom << EOF
#!/bin/sh
exec tail -n +3 \$0
set superusers="root"
password_pbkdf2 root $HASH
EOF
            read -r -p "Run update-grub now to apply the new GRUB password? (y/N): " CONFIRM_UG_PW
            if [[ "${CONFIRM_UG_PW,,}" == "y" ]]; then
                update-grub || log "[account_policies] update-grub failed or returned non-zero."
                log "[account_policies] GRUB password updated (verify)."
            else
                log "[account_policies] GRUB password written to /etc/grub.d/40_custom but update-grub skipped (run manually when ready)."
            fi
        else
            log "[account_policies] grub-mkpasswd-pbkdf2 did not produce a hash; skipping GRUB password write."
        fi
    else
        log "[account_policies] Skipped GRUB password setup per user choice."
    fi
else
    log "[account_policies] grub-mkpasswd-pbkdf2 not found; skipping GRUB password option."
fi

log "[account_policies] Completed account policy tasks."
