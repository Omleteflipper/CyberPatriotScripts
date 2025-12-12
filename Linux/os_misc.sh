# os_misc.sh
# - Variables & env detection
# - Logging helpers: log, log_info
# - ring_bell, line_sep, prompt_continue
# - Arg parsing (--help --debug --version --license)
# - Sudo / privilege check
#!/bin/bash

##### IMPORTANT VARS #####
unalias -a
version="v1.7.9"
start_time=$(date +"%Y-%m-%d, %I:%M:%S %p")
start_secs=$(date +%s.%N)
LOGFILE="./linux_script.log"
output_file="./linux_script_output.log"
starting_dir=$(pwd)
distro_id=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
distro_codename=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
debug=0
help=0
license=0
version_arg=0

##### FUNCTIONS #####
log() {
    echo "$@" >> "$LOGFILE"
    if [[ $debug -eq 1 ]]; then
        echo "$@" >> "$output_file"
    fi
    echo "$@"
}
log_info() { # does not print to terminal, only to log
    echo "$@" >> "$LOGFILE"
    if [[ $debug -eq 1 ]]; then
        echo "$@" >> "$output_file"
    fi
}
ring_bell() {
    echo -e "\a" &
}
line_sep() {
    echo "----------------------------------"
}
prompt_continue() {
    read -r -p "Press ENTER to continue or Ctrl+C to abort..."
}

##### MANAGE ARGS #####
if [ $# -gt 0 ]; then
    for arg in "$@"; do
        case "$arg" in
            --help) help=1 ;;
            --version) version_arg=1 ;;
            --license) license=1 ;;
            --debug) debug=1 ;;
            *) echo "Unknown option: $arg"; exit 1 ;;
        esac
    done
fi

if [[ $help -eq 1 ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "    --debug      Enable debug mode"
    echo "    --help       Display this help message"
    echo "    --license    Show license information"
    echo "    --version    Show version information"
    exit 0
elif [[ $version_arg -eq 1 ]]; then
    echo "$0 $version"; exit 0
elif [[ $license -eq 1 ]]; then
    curl https://www.gnu.org/licenses/gpl-3.0.txt | less; exit 0
elif [[ $debug -eq 1 ]]; then
    set -x
    touch "$LOGFILE" "$output_file"
    exec > >(tee -a "$output_file") 2>&1
    log "Debug mode enabled."
else
    touch "$LOGFILE"
    log_info "Start time: $start_time"
fi

##### CHECK FOR SUDO #####
log_info "Checking for `sudo` access..."
if [[ $EUID -ne 0 ]]; then
    log "`sudo` access is required. Please run 'sudo !!'"
    exit 1
fi

# Convenience: create logs directory if needed
mkdir -p ./logs 2>/dev/null || true
