#!/bin/bash
# ========== OS Updates ==========
# Update system packages and check system load.

echo "[+] Updating package lists..."
apt update -y
echo "[+] apt update completed."

##### CHECK SYSTEM LOAD #####
echo "[+] Checking for unusual system load..."
load=$(cat /proc/loadavg | cut -d ' ' -f1)
if (( $(echo "$load > 10" | bc -l) )); then
    echo "[!] High system load detected: $load" > ./high_system_load.log
fi
