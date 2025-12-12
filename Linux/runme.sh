# runme.sh
# - Master orchestrator: executes modules in a safe order
# - Usage: sudo ./runme.sh [--yes] [--only module1,module2]
# - Creates logs directory; reports summary at the end
#!/bin/bash
set -euo pipefail
AUTO=0
ONLY=""
if [[ "${1:-}" == "--yes" ]]; then
    AUTO=1
fi
if [[ "${1:-}" == "--only" ]]; then
    ONLY="${2:-}"
fi

LOGDIR="./run_logs"
mkdir -p "$LOGDIR"

# verify os_misc exists
if [[ ! -f ./os_misc.sh ]]; then
    echo "Missing os_misc.sh. Aborting."
    exit 1
fi
chmod +x ./os_misc.sh

run_script() {
    local script="$1"
    local name
    name=$(basename "$script")
    if [[ -n "$ONLY" ]]; then
        if ! grep -qw "$name" <<< "$ONLY"; then
            echo "Skipping $name (not in --only list)"
            return
        fi
    fi
    echo "---- Running $name ----"
    if [[ $AUTO -eq 0 ]]; then
        read -r -p "Run $name now? (Y/n): " ans
        if [[ "$ans" =~ ^[Nn] ]]; then
            echo "Skipping $name."
            return
        fi
    fi
    bash "$script" 2>&1 | tee "${LOGDIR}/${name}.log"
    echo "---- Completed $name ----"
}

# Execution order (safe first)
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
    if [[ -f "./${m}" ]]; then
        run_script "./${m}"
    else
        echo "Module ${m} not found; skipping."
    fi
done

echo "All modules processed. Logs available in $LOGDIR"
if [[ $AUTO -eq 0 ]]; then
    read -r -p "Reboot now? (y/N): " r
    if [[ "$r" =~ ^[Yy] ]]; then
        reboot
    fi
fi
