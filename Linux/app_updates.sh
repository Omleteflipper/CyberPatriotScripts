# app_updates.sh
# - Update APT sources (Ubuntu / Debian / Mint handling)
# - Configure unattended-upgrades & apt periodic settings
# - apt update/upgrade and create package manifest
#!/bin/bash

source ./os_misc.sh
log "[app_updates] Updating APT repositories and configuring unattended upgrades."

# Backup sources and rewrite per distro if needed (same logic as original script)
cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true

if [[ $distro_id == "linuxmint" ]]; then
    {
        echo "deb http://packages.linuxmint.com $distro_codename main upstream import backport"
        echo "deb-src http://packages.linuxmint.com $distro_codename main upstream import backport"
    } > /etc/apt/sources.list
elif [[ $distro_id == "ubuntu" ]]; then
    {
        echo "deb https://mirrors.kernel.org/ubuntu/ $distro_codename main restricted universe multiverse"
        echo "deb https://mirrors.kernel.org/ubuntu/ $distro_codename-updates main restricted universe multiverse"
        echo "deb https://security.ubuntu.com/ubuntu/ $distro_codename-security main restricted universe multiverse"
    } > /etc/apt/sources.list
elif [[ $distro_id == "debian" ]]; then
    {
        echo "deb http://deb.debian.org/debian/ $distro_codename main contrib non-free non-free-firmware"
        echo "deb-src http://deb.debian.org/debian/ $distro_codename main contrib non-free non-free-firmware"
        echo "deb http://security.debian.org/debian-security $distro_codename-security main contrib non-free non-free-firmware"
    } > /etc/apt/sources.list
else
    log "[app_updates] Unsupported distro: $distro_id $distro_codename"
fi

# Enforce package signature verification & verification logs
echo 'APT::Get::AllowUnauthenticated "false";' > /etc/apt/apt.conf.d/99verify-peer
dpkg --verify > /var/log/package-verification.log 2>&1
debsums -c >> /var/log/package-verification.log 2>&1
cp /var/log/package-verification.log ./package_verification.log

# Unattended-upgrades configuration (kept from original)
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

# Update and upgrade
log "[app_updates] Running apt update/upgrade (may take a while)."
apt update -y
apt upgrade -y
apt full-upgrade -y
apt autoremove -y --purge

# Create package manifest
dpkg --get-selections > /root/package-manifest.txt
chmod 600 /root/package-manifest.txt || true

log "[app_updates] Completed."
