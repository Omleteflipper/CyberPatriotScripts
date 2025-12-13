# policy_violations.sh
# - Detect Policy Violations:
#   - Malware indicators (RATs, backdoors, keyloggers)
#   - Prohibited files (archives, confidential docs)
#   - Unwanted software (games, servers, hacking tools)
# - Produces logs only; destructive removals are manual by default
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/os_misc.sh"

log "[policy_violations] Detecting policy violations (non-destructive)."

# ========== MALWARE INDICATORS ==========
log "[policy_violations] Searching for possible backdoors and RAT indicators..."

# Look for suspicious autorun or persistence in crontab/systemd timers
grep -RIs --exclude-dir={/proc,/sys,/dev} -E "nc -e|/bin/bash -i|/bin/sh -i|bash -i|/dev/tcp" /etc /home /var 2>/dev/null | tee ./policy_backdoor_scan.log

# Search for suspicious binaries in /tmp or commonly abused directories
find /tmp /var/tmp /dev/shm -type f -perm -u=x -print > ./policy_exec_in_tmp.log 2>/dev/null

# Look for known keylogger filenames / suspicious LD_PRELOAD entries
grep -RIs --exclude-dir={/proc,/sys,/dev} -E "LD_PRELOAD|keylogger|logkeys|xinput_calibrator" /etc /home /var 2>/dev/null | tee ./policy_ldpreload_scan.log

# ========== PROHIBITED FILES ==========
log "[policy_violations] Searching for prohibited file types (archives, confidential docs, installers)..."
find /home -type f \( -iname "*.zip" -o -iname "*.tar.gz" -o -iname "*.tgz" -o -iname "*.7z" -o -iname "*.rar" -o -iname "*.exe" -o -iname "*.msi" -o -iname "*.deb" \) -print > ./policy_archives.log

# Example: search for potential confidential keywords (non-exhaustive)
grep -RIl --exclude-dir={/proc,/sys,/dev} -E "confidential|ssn|social security|passwords|private key|secret" /home 2>/dev/null > ./policy_confidential_matches.log || true

# ========== UNWANTED SOFTWARE ==========
log "[policy_violations] Detecting installed unwanted or potentially prohibited packages."
UNWANTED=(steam minecraft-server minecraft-server-installer wine metasploit-framework john nmap hydra aircrack-ng)
for p in "${UNWANTED[@]}"; do
    dpkg -l 2>/dev/null | awk '{print $2}' | grep -qw "$p" && echo "$p" >> ./policy_unwanted_packages_detected.log
done

# ========== SUGGESTED NEXT STEPS (manual) ==========
log "[policy_violations] Detection complete. Review the generated logs:"
log "  ./policy_backdoor_scan.log"
log "  ./policy_exec_in_tmp.log"
log "  ./policy_ldpreload_scan.log"
log "  ./policy_archives.log"
log "  ./policy_confidential_matches.log"
log "  ./policy_unwanted_packages_detected.log"

log "[policy_violations] This script does NOT delete anything. Use 'policy_violations_clean.sh' to remove after review."
