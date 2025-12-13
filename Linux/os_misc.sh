#!/bin/bash
# os_misc.sh
# - Distro detection (ID, NAME, VERSION_ID, CODENAME)
# - Logging helpers (log, log_info)
# - Repo helpers: ensure_universe_repo(), enable_debian_nonfree()
# - apt wrappers: apt_get_update(), install_packages()
# - Sudo check and small utilities

##### VARIABLES & METADATA #####
unalias -a
version="v1.8.0"
start_time=$(date +"%Y-%m-%d, %I:%M:%S %p")
LOGFILE="./linux_script.log"
output_file="./linux_script_output.log"
debug=0

# default distro vars (will be populated by detect_distro)
distro_id=""
distro_name=""
distro_like=""
version_id=""
codename=""

##### UTILITY FUNCTIONS #####
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}
log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}
line_sep() { echo "----------------------------------"; }
ring_bell() { echo -e "\a" & }
prompt_continue() { read -r -p "Press ENTER to continue or Ctrl+C to abort..."; }

##### ARG PARSING (minimal) #####
for arg in "$@"; do
    case "$arg" in
        --debug) debug=1 ;;
        --help) echo "Source this file only; used by other scripts."; exit 0 ;;
    esac
done

##### SUDO CHECK #####
if [[ $EUID -ne 0 ]]; then
    echo "This script requires root (sudo). Please run with sudo."
    exit 1
fi

##### DISTRIBUTION DETECTION #####
detect_distro() {
    # Prefer /etc/os-release (standard)
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        distro_id=${ID:-}
        distro_name=${NAME:-}
        distro_like=${ID_LIKE:-}
        version_id=${VERSION_ID:-}
        # CODENAME may be in VERSION_CODENAME or in VERSION
        codename=${VERSION_CODENAME:-}
        if [[ -z "$codename" && -n "$VERSION" ]]; then
            # try to extract code name from VERSION if present in parentheses
            codename=$(echo "$VERSION" | sed -n 's/.*(\(.*\)).*/\1/p' || true)
        fi
    else
        # fallback
        distro_id=$(uname -s)
        distro_name="$distro_id"
        version_id=$(uname -r)
        codename=""
    fi

    # Normalize common names
    distro_id=$(echo "$distro_id" | tr '[:upper:]' '[:lower:]')
    codename=$(echo "$codename" | tr '[:upper:]' '[:lower:]')

    log "[os_misc] Detected distro: ID=$distro_id NAME='$distro_name' VERSION=$version_id CODENAME=$codename"
}

##### APT / REPO HELPERS #####
# Ensure apt-get update runs at most once per session
APT_UPDATED=0
apt_get_update() {
    if [[ $APT_UPDATED -eq 0 ]]; then
        log "[os_misc] Running apt-get update..."
        apt-get update -y || true
        APT_UPDATED=1
    else
        log "[os_misc] apt-get update already run in this session."
    fi
}

# Ensures 'universe' (and multiverse) is enabled on Ubuntu / Mint
ensure_universe_repo() {
    # Only relevant for Ubuntu-family distributions
    if [[ "$distro_id" == "ubuntu" || "$distro_id" == "linuxmint" || "$distro_like" == *"ubuntu"* ]]; then
        log "[os_misc] Ensuring 'universe' repository is enabled for $distro_id."
        apt_get_update
        # software-properties-common provides add-apt-repository
        apt-get install -y software-properties-common apt-transport-https gnupg || true
        # attempt to enable universe/multiverse
        add-apt-repository universe -y || true
        add-apt-repository multiverse -y || true
        apt_get_update
        log "[os_misc] Universe/multiverse repositories ensured (if supported)."
    else
        log "[os_misc] Not Ubuntu-family (skipping universe enable)."
    fi
}

# Optionally enable Debian non-free (if needed)
enable_debian_nonfree() {
    if [[ "$distro_id" == "debian" || "$distro_like" == *"debian"* ]]; then
        log "[os_misc] Ensuring Debian non-free repositories are present (may require manual review)."
        if grep -qE "non-free" /etc/apt/sources.list 2>/dev/null ; then
            log "[os_misc] non-free already present in sources.list"
        else
            # append non-free to existing deb lines (best-effort)
            cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true
            sed -i 's/ main$/ main contrib non-free/' /etc/apt/sources.list || true
            apt_get_update
            log "[os_misc] Added contrib/non-free to sources.list (verify manually)."
        fi
    fi
}

# Install packages with apt-get; automatically calls repo helpers for Ubuntu/Mint
# Usage: install_packages pkg1 pkg2 ...
install_packages() {
    if [[ $# -eq 0 ]]; then
        log "[os_misc] install_packages called with no args."
        return 0
    fi
    # If Ubuntu-family, ensure universe/multiverse available
    if [[ "$distro_id" == "ubuntu" || "$distro_id" == "linuxmint" || "$distro_like" == *"ubuntu"* ]]; then
        ensure_universe_repo
    fi
    apt_get_update
    log "[os_misc] Installing packages: $*"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" || {
        log "[os_misc] apt-get install failed for: $*  (check logs)"
        return 2
    }
    return 0
}

##### INITIALIZE DETECTION ON SOURCE #####
detect_distro

# Expose distro vars to environment for convenience
export distro_id distro_name distro_like version_id codename
