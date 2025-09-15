#!/usr/bin/env bash
# Ubuntu Updater (self-elevating, user-friendly)
# Description: A comprehensive update script for Ubuntu-based systems.
#              Updates APT, Snap, Flatpak, and firmware.
# Usage:
#   ./ubuntu-update.sh [--reboot] [--no-snap] [--no-flatpak] [--no-fw]
#                      [--no-clean] [--assume-yes|-y] [--fix-broken] [--dry-run]

# --- Strict Mode & Safety ---
# -E: ERR trap is inherited by shell functions, command substitutions, and commands
#     executed in a subshell environment.
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error when substituting.
# -o pipefail: The return value of a pipeline is the status of the last command
#              to exit with a non-zero status, or zero if no command exited
#              with a non-zero status.
set -Eeuo pipefail

# --- User Interface: Colors and Symbols ---
# Using tput for wider compatibility
C_RESET=$(tput sgr0 || printf '\033[0m')
C_BOLD=$(tput bold || printf '\033[1m')
C_CYAN=$(tput setaf 6 || printf '\033[1;36m')
C_YELLOW=$(tput setaf 3 || printf '\033[1;33m')
C_RED=$(tput setaf 1 || printf '\033[1;31m')
C_GREEN=$(tput setaf 2 || printf '\033[1;32m')
S_INFO="${C_CYAN}==>${C_RESET}"
S_WARN="${C_YELLOW}[WARN]${C_RESET}"
S_ERROR="${C_RED}[ERROR]${C_RESET}"
S_SUCCESS="${C_GREEN}[OK]${C_RESET}"
S_TICK="${C_GREEN}✓${C_RESET}"
S_CROSS="${C_RED}✗${C_RESET}"

# --- Global Flags & Configuration ---
DO_SNAP=1
DO_FLATPAK=1
DO_FW=1
DO_CLEAN=1
DO_REBOOT=0
ASSUME_YES=0
FIX_BROKEN=0
DRY_RUN=0
declare -a SCRIPT_ARGS # Store original arguments for self-elevation

# --- Helper Functions ---
log() { printf '\n%s %s%s%s\n' "$S_INFO" "$C_BOLD" "$*" "$C_RESET"; }
warn() { printf '%s %s\n' "$S_WARN" "$*" >&2; }
error() {
    printf '%s %s\n' "$S_ERROR" "$*" >&2
    exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }
is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }

# A function to run commands and show a spinner.
# Usage: run_task "Doing something..." some_command arg1 arg2
run_task() {
    local msg="$1"
    shift
    printf '%s ' "$msg"

    # Don't show spinner or result for dry runs, just show what would run
    if ((DRY_RUN)); then
        printf "\n${C_YELLOW}[DRY-RUN] Would execute: %s${C_RESET}\n" "$*"
        return 0
    fi

    # Execute the command, redirecting output to a temporary file
    local tmp_output
    tmp_output=$(mktemp)
    if "$@" >"$tmp_output" 2>&1; then
        printf '%s\n' "$S_TICK"
        rm -f "$tmp_output"
        return 0
    else
        printf '%s\n' "$S_CROSS"
        warn "Task failed. Full output:"
        # Using cat inside a subshell to avoid issues with set -e
        (cat "$tmp_output") >&2
        rm -f "$tmp_output"
        return 1
    fi
}

# --- Argument Parsing ---
show_help() {
    sed -n '1,10p' "$0"
    exit 0
}

# Store args for sudo exec
SCRIPT_ARGS=("$@")

while (($#)); do
    case "$1" in
    --no-snap) DO_SNAP=0 ;;
    --no-flatpak) DO_FLATPAK=0 ;;
    --no-fw | --no-firmware) DO_FW=0 ;;
    --no-clean) DO_CLEAN=0 ;;
    --reboot) DO_REBOOT=1 ;;
    --assume-yes | -y) ASSUME_YES=1 ;;
    --fix-broken) FIX_BROKEN=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h | --help) show_help ;;
    *) error "Unknown option: $1" ;;
    esac
    shift
done

# --- Self-Elevate to Root ---
if [[ ${EUID:-0} -ne 0 ]]; then
    log "Requesting root privileges..."
    # Re-launch the script with sudo, preserving critical environment variables.
    exec sudo --reset-timestamp --preserve-env=DEBIAN_FRONTEND,NEEDRESTART_MODE "$0" "${SCRIPT_ARGS[@]}"
fi

# --- Logging Setup ---
# Must be after elevation to ensure permissions in home directory
INVOKER="${SUDO_USER:-$USER}"
INV_HOME="$(getent passwd "$INVOKER" | cut -d: -f6)"
if [[ -n "$INV_HOME" && -d "$INV_HOME" ]]; then
    LOG_DIR="$INV_HOME/.ubuntu-update"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/run-$(date +%Y%m%d-%H%M%S).log"
else
    # Fallback if home directory isn't available
    LOG_FILE="/tmp/ubuntu-update-$(date +%s).log"
fi
touch "$LOG_FILE" && chown "$INVOKER:$INVOKER" "$LOG_FILE"
# Tee output to the log file and also to the console
exec > >(tee -a "$LOG_FILE") 2>&1

# --- Script Header ---
echo "-------------------------------------"
log "Ubuntu Updater Started"
echo "Invoked by: $INVOKER"
echo "Log file:   $LOG_FILE"
echo "-------------------------------------"

# --- Environment Setup ---
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_Y=()
((ASSUME_YES)) && APT_Y+=("-y")
APT_FIX=()
((FIX_BROKEN)) && APT_FIX+=("--fix-broken")
APT_DRY=()
((DRY_RUN)) && APT_DRY+=("--dry-run")

if is_wsl; then
    warn "WSL detected: skipping firmware updates."
    DO_FW=0
fi

# --- Main Logic ---
main() {
    # --- Safety: Wait for dpkg lock ---
    if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
        warn "dpkg is busy. Waiting up to 60 seconds..."
        if ! timeout 60 bash -c 'while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done'; then
            warn "dpkg remained locked. Continuing, but APT commands may fail."
        fi
    fi

    # --- APT ---
    log "APT Package Manager"
    run_task "Updating package lists..." apt update
    if ((FIX_BROKEN)); then
        run_task "Fixing broken installs..." apt-get install -f -y
    fi
    # Use apt-get for better scriptability over apt
    run_task "Upgrading system packages..." apt-get full-upgrade "${APT_Y[@]}" "${APT_DRY[@]}"

    if ((DO_CLEAN)); then
        run_task "Removing unused packages..." apt-get autoremove --purge -y
        run_task "Cleaning APT cache..." apt-get clean
    fi

    # --- Snap ---
    if ((DO_SNAP)) && have snap; then
        log "Snap Package Manager"
        # The `|| true` is kept here because `snap refresh --list` can exit non-zero
        # if there are no updates, which would otherwise stop the script.
        ((DRY_RUN)) && snap refresh --list || true
        ((!DRY_RUN)) && run_task "Refreshing Snap packages..." snap refresh || warn "Snap refresh had non-critical issues."
    elif ((DO_SNAP)); then
        warn "snap command not found; skipping Snap updates."
    fi

    # --- Flatpak ---
    if ((DO_FLATPAK)) && have flatpak; then
        log "Flatpak Package Manager"
        # System updates
        run_task "Updating system Flatpaks..." flatpak update --system --noninteractive -y
        # User updates (run as the original user)
        if [[ -n "$INVOKER" && -n "$INV_HOME" ]]; then
            log "Checking for user Flatpaks for '$INVOKER'..."
            if sudo -u "$INVOKER" XDG_RUNTIME_DIR=/run/user/"$(id -u "$INVOKER")" flatpak list --user | grep -q .; then
                run_task "Updating user Flatpaks..." sudo -u "$INVOKER" XDG_RUNTIME_DIR=/run/user/"$(id -u "$INVOKER")" flatpak update --user --noninteractive -y
            else
                echo "No user Flatpaks found."
            fi
        fi
    elif ((DO_FLATPAK)); then
        warn "flatpak command not found; skipping Flatpak updates."
    fi

    # --- Firmware ---
    if ((DO_FW)) && have fwupdmgr; then
        log "Firmware (fwupdmgr)"
        run_task "Refreshing firmware sources..." fwupdmgr refresh --force
        # Check for updates before trying to apply them
        if fwupdmgr get-updates | grep -q "No upgrades"; then
            echo "No firmware upgrades available."
        else
            run_task "Applying firmware updates..." fwupdmgr update -y
        fi
    elif ((DO_FW)); then
        warn "fwupdmgr not found. Install with: sudo apt install fwupd"
    fi

    # --- Final Health Checks ---
    log "Final System Health Checks"
    run_task "Ensuring all packages are configured..." dpkg --configure -a
    run_task "Running final dependency check..." apt-get install -f -y

    # --- Finish and Reboot ---
    log "Update complete!"
    echo "${S_SUCCESS} Log saved to: $LOG_FILE"

    if [[ -f /var/run/reboot-required ]]; then
        warn "Reboot is required to apply some updates."
        if ((DO_REBOOT)); then
            log "Rebooting now as requested (--reboot)..."
            reboot
        else
            warn "To reboot, run: sudo reboot"
        fi
    elif ((DO_REBOOT)); then
        log "No reboot required, but rebooting as requested (--reboot)..."
        reboot
    fi
}

# --- Cleanup and Error Handling ---
cleanup() {
    # This function is called on EXIT
    # Add any necessary cleanup tasks here
    printf "\n%s Script finished.\n" "$S_INFO"
}
trap cleanup EXIT

# --- Execute Main Function ---
main
