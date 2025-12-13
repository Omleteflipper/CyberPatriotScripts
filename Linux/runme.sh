#!/bin/bash
# runme.sh
# - Master orchestrator
# - Usage: sudo ./runme.sh [--yes] [--only module1,module2]

set -Eeuo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_DIR="$BASE_DIR/scripts"
LOG_DIR="$BASE_DIR/logs"

mkdir -p "$LOG_DIR"

MASTER_LOG="$LOG_DIR/run-$(date '+%Y-%m-%d_%H-%M-%S').log"

# Capture everything (stdout + stderr) to terminal AND master log
exec > >(tee -a "$MASTER_LOG") 2> >(tee -a "$MASTER_LOG" >&2)

echo "Log file: $MASTER_LOG"
echo "Started at $(date)"
echo

AUTO=0
ONLY=""

if [[ "${1:-}" == "--yes" ]]; then
    AUTO=1
fi
if [[ "${1:-}" == "--only" ]]; then
    ONLY="${2:-}"
fi

# Verify os_misc.sh
if [[ ! -f "$SCRIPT_DIR/os_misc.sh" ]]; then
    echo "[FATAL] Missing scripts/os_misc.sh. Aborting."
    exit 1
fi
chmod +x "$SCRIPT_DIR/os_misc.sh"

run_script() {
    local script="$1"
    local name
    name="$(basename "$script")"
    local log="$LOG_DIR/${name}.log"

    if [[ -n "$ONLY" ]] && ! grep -qw "$name" <<< "$ONLY"; then
        echo "Skipping $name (not in --only list)"
        return
    fi

    echo "========== Running $name =========="

    if [[ $AUTO -eq 0 ]]; then
        read -r -p "Run $name now? (Y/n): " ans
        if [[ "$ans" =~ ^[Nn] ]]; then
            echo "Skipping $name."
            return
        fi
    fi

    # Run script and capture exit code correctly
    set +e
    bash "$script" > >(tee -a "$log") 2> >(tee -a "$log" >&2)
    status=$?
    set -e

    if [[ $status -ne 0 ]]; then
        echo "[ERROR] $name failed with exit code $status"
    else
        echo "[OK] $name completed successfully"
    fi

    echo "========== Completed $name =========="
    echo
}

MODULES=(
  os_misc.sh
  app_updates.sh
  app_security.sh
  malware_checks.sh
  defense.sh
  local_policies.sh
  service_audit.sh
  user_audit.sh
  account_policies.sh
  policy_violations.sh
)

for m in "${MODULES[@]}"; do
    script="$SCRIPT_DIR/$m"
    if [[ -f "$script" ]]; then
        run_script "$script"
    else
        echo "[WARN] Module $m not found; skipping."
    fi
done

echo "All modules processed."
echo "Logs available in $LOG_DIR"

if [[ $AUTO -eq 0 ]]; then
    read -r -p "Reboot now? (y/N): " r
    if [[ "$r" =~ ^[Yy] ]]; then
        reboot
    fi
fi
