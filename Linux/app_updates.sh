#!/bin/bash
# app_updates.sh
# - Safe repo handling (adds required distro repos into /etc/apt/sources.list.d/cyberpatriot.list)
# - Ensures universe/multiverse for Ubu/Mint and non-free for Debian (additive, not overwrite)
# - Installs debsums for package verification
# - Writes apt verification config (99verify-peer)
# - Runs dpkg --verify and debsums and saves logs
# - Configures unattended-upgrades & apt periodic settings
# - Runs apt-get update/upgrade/full-upgrade/autoremove (noninteractive)
# - Creates package manifest under /root/package-manifest.txt
#
# NOTE: This script does NOT overwrite /etc/apt/sources.list; it writes extra lines to
# /etc/apt/sources.list.d/cyberpatriot.list so the original file is preserved.

set -euo pipefail
source ./os_misc.sh

log "[app_updates] Starting package update and repo helper."

# Back up current system sources.list (non-destructive)
cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true

# Build a distro-appropriate supplementary sources file (additive)
CYBER_SOURCES="/etc/apt/sources.list.d/cyberpatriot.list"
mkdir -p /etc/apt/sources.list.d 2>/dev/null || true

# Prepare candidate repository lines per distro (additive only)
repo_lines=""
if [[ "$distro_id" == "linuxmint" ]]; then
    if ! grep -q "packages.linuxmint.com" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null || true; then
        repo_lines+="deb http://packages.linuxmint.com ${codename} main upstream import backport\n"
        repo_lines+="deb-src http://packages.linuxmint.com ${codename} main upstream import backport\n"
    fi
elif [[ "$distro_id" == "ubuntu" ]]; then
    # Add canonical ubuntu mirrors if not present
    if ! grep -q "mirrors.kernel.org/ubuntu" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null || true; then
        repo_lines+="deb https://mirrors.kernel.org/ubuntu/ ${codename} main restricted universe multiverse\n"
        repo_lines+="deb https://mirrors.kernel.org/ubuntu/ ${codename}-updates main restricted universe multiverse\n"
        repo_lines+="deb https://security.ubuntu.com/ubuntu/ ${codename}-security main restricted universe multiverse\n"
    fi
elif [[ "$distro_id" == "debian" ]]; then
    if ! grep -q "deb.debian.org/debian" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null || true; then
        repo_lines+="deb http://deb.debian.org/debian/ ${codename} main contrib non-free non-free-firmware\n"
        repo_lines+="deb-src http://deb.debian.org/debian/ ${codename} main contrib non-free non-free-firmware\n"
        repo_lines+="deb http://security.debian.org/debian-security ${codename}-security main contrib non-free non-free-firmware\n"
    fi
else
    log "[app_updates] Unknown or unsupported distro_id='$distro_id' — skipping cyberpatriot.list creation."
fi

# Write the additive repo file if we have suggested lines
if [[ -n "$repo_lines" ]]; then
    log "[app_updates] Writing additional repo lines to $CYBER_SOURCES (additive)."
    # only append lines not already present
    touch "$CYBER_SOURCES"
    while IFS= read -r line; do
        # skip blank lines
        [[ -z "$line" ]] && continue
        # if line not already present anywhere, append
        if ! grep -RqxF -- "$line" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
            echo "$line" >> "$CYBER_SOURCES"
        else
            log "[app_updates] Repo line already present, skipping: $line"
        fi
    done < <(printf "%b" "$repo_lines")
    log "[app_updates] Supplementary source file written to $CYBER_SOURCES (verify manually if needed)."
else
    log "[app_updates] No supplementary repo lines needed for $distro_id."
fi

# Ensure apt helpers (universe / multiverse / non-free) using os_misc helper functions
ensure_universe_repo
enable_debian_nonfree

# Ensure debsums is available for package verification
install_packages debsums || log "[app_updates] Could not install debsums (verify manually)."

# Enforce package signature verification config (non-destructive)
log "[app_updates] Writing APT verification config (99verify-peer)."
cat > /etc/apt/apt.conf.d/99verify-peer <<'EOF'
APT::Get::AllowUnauthenticated "false";
EOF

# Run package verification & debsums (best-effort)
log "[app_updates] Running dpkg --verify and debsums (may show many results)."
dpkg --verify > /var/log/package-verification.log 2>&1 || true
debsums -c >> /var/log/package-verification.log 2>&1 || true
cp /var/log/package-verification.log ./package_verification.log 2>/dev/null || true

# Unattended-upgrades config (keep from original)
log "[app_updates] Configuring unattended-upgrades and periodic APT settings."
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

cat > /etc/apt/apt.conf.d/52unattended-upgrades-local << EOF
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

# Update and upgrade (use apt-get to be script-friendly)
log "[app_updates] Running apt-get update/upgrade (this may take a while)."
apt_get_update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || log "[app_updates] apt-get upgrade returned non-zero"
DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y || log "[app_updates] apt-get full-upgrade returned non-zero"
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge || true

# Create package manifest (audit)
log "[app_updates] Creating package manifest at /root/package-manifest.txt"
dpkg --get-selections > /root/package-manifest.txt 2>/dev/null || log "[app_updates] dpkg --get-selections failed"
chmod 600 /root/package-manifest.txt 2>/dev/null || true

log "[app_updates] Completed app_updates tasks."
