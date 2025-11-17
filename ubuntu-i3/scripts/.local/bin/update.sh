#!/usr/bin/env bash
# Ubuntu Updater (self-elevating, pretty, live output)
# Updates APT, Snap, Flatpak, and firmware with real-time feedback.

set -Eeuo pipefail

# ---------- UI: Colors & Symbols ----------
C_RESET=$(tput sgr0 2>/dev/null || printf '\033[0m')
C_BOLD=$(tput bold 2>/dev/null || printf '\033[1m')
C_DIM=$(tput dim 2>/dev/null || printf '\033[2m')
C_CYAN=$(tput setaf 6 2>/dev/null || printf '\033[36m')
C_YELLOW=$(tput setaf 3 2>/dev/null || printf '\033[33m')
C_RED=$(tput setaf 1 2>/dev/null || printf '\033[31m')
C_GREEN=$(tput setaf 2 2>/dev/null || printf '\033[32m')
S_INFO="${C_CYAN}==>${C_RESET}"
S_WARN="${C_YELLOW}[WARN]${C_RESET}"
S_ERROR="${C_RED}[ERROR]${C_RESET}"
S_OK="${C_GREEN}[OK]${C_RESET}"
S_TICK="${C_GREEN}✓${C_RESET}"
S_CROSS="${C_RED}✗${C_RESET}"

log() { printf '%s %s%s%s\n' "$S_INFO" "$C_BOLD" "$*" "$C_RESET"; }
warn() { printf '%s %s\n' "$S_WARN" "$*" >&2; }
error() {
    printf '%s %s\n' "$S_ERROR" "$*" >&2
    exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }
is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }
hr() { printf '%s\n' "${C_DIM}────────────────────────────────────────────────────${C_RESET}"; }
section() {
    printf '\n%s %s%s%s\n' "$S_INFO" "$C_BOLD" "$1" "$C_RESET"
    hr
}

# ---------- Flags ----------
DO_SNAP=1
DO_FLATPAK=1
DO_FW=1
DO_CLEAN=1
DO_REBOOT=0
ASSUME_YES=0
FIX_BROKEN=0
DRY_RUN=0
declare -a SCRIPT_ARGS
SCRIPT_ARGS=("$@")

show_help() {
    cat <<EOF
Ubuntu Updater – options:
  --reboot              Reboot automatically at the end
  --no-snap             Skip Snap updates
  --no-flatpak          Skip Flatpak updates
  --no-fw|--no-firmware Skip firmware (fwupdmgr)
  --no-clean            Skip apt autoremove/clean
  --assume-yes|-y       Run apt with -y
  --fix-broken          Run 'apt-get install -f -y' early and at end
  --dry-run             Show commands without executing
  -h|--help             Show help
EOF
    exit 0
}

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

# ---------- Self-elevate ----------
if [[ ${EUID:-0} -ne 0 ]]; then
    log "Requesting root privileges..."
    exec sudo --reset-timestamp --preserve-env=DEBIAN_FRONTEND,NEEDRESTART_MODE "$0" "${SCRIPT_ARGS[@]}"
fi

# ---------- Logging (screen + file) ----------
INVOKER="${SUDO_USER:-$USER}"
INV_HOME="$(getent passwd "$INVOKER" | cut -d: -f6 || true)"
if [[ -n "${INV_HOME:-}" && -d "$INV_HOME" ]]; then
    LOG_DIR="$INV_HOME/.ubuntu-update"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/run-$(date +%Y%m%d-%H%M%S).log"
else
    LOG_FILE="/tmp/ubuntu-update-$(date +%s).log"
fi
touch "$LOG_FILE" && chown "$INVOKER:$INVOKER" "$LOG_FILE" || true

# Line-buffered tee so progress shows smoothly
if have stdbuf; then
    exec > >(stdbuf -oL -eL tee -a "$LOG_FILE") 2>&1
else
    exec > >(tee -a "$LOG_FILE") 2>&1
fi

# ---------- Header ----------
printf '\n'
hr
log "Ubuntu Updater Started"
printf 'User: %s\n' "$INVOKER"
printf 'Log : %s\n' "$LOG_FILE"
hr

# ---------- Environment ----------
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

APT_Y=()
((ASSUME_YES)) && APT_Y+=("-y")
APT_FIX=()
((FIX_BROKEN)) && APT_FIX+=("--fix-broken")
APT_DRY=()
((DRY_RUN)) && APT_DRY+=("--dry-run")

# Split APT options: progress not valid for `update`
APT_OPTS_COMMON=(-o Dpkg::Use-Pty=1 -o Dpkg::Progress-Fancy=1 -o APT::Color=1 -o Acquire::Retries=3)
APT_OPTS_PROGRESS=(--show-progress "${APT_OPTS_COMMON[@]}")

if is_wsl; then
    warn "WSL detected: skipping firmware updates."
    DO_FW=0
fi

# ---------- Task runner (live output, no temp files) ----------
run_task() {
    local msg="$1"
    shift
    local start end dur rc
    printf '\n%s %s\n' "$S_INFO" "$msg"
    start=$(date +%s)

    if ((DRY_RUN)); then
        printf '%s[DRY-RUN] Would execute:%s ' "${C_YELLOW}" "${C_RESET}"
        printf '%q ' "$@"
        printf '\n'
        printf '%s %s %s\n' "$S_TICK" "$msg" "${C_DIM}(0s)${C_RESET}"
        return 0
    fi

    # Temporarily disable -e and ERR so failures are handled here cleanly
    set +eE
    "$@"
    rc=$?
    set -eE

    end=$(date +%s)
    dur=$((end - start))
    if ((rc == 0)); then
        printf '%s %s %s\n' "$S_TICK" "$msg" "${C_DIM}(${dur}s)${C_RESET}"
        return 0
    else
        printf '%s %s %s\n' "$S_CROSS" "$msg" "${C_DIM}(${dur}s)${C_RESET}"
        return "$rc"
    fi
}

# ---------- Kitty Update ----------
update_kitty() {
    if [[ -z "${INVOKER:-}" || -z "${INV_HOME:-}" ]]; then
        warn "Unable to determine invoking user; skipping Kitty update."
        return
    fi
    local kitty_app="$INV_HOME/.local/kitty.app"
    local kitty_bin="$kitty_app/bin/kitty"
    local kitty_link="$INV_HOME/.local/bin/kitty"
    if [[ ! -x "$kitty_bin" ]]; then
        warn "Kitty not found at $kitty_bin; skipping Kitty update."
        return
    fi
    section "Kitty terminal"
    run_task "Updating Kitty from upstream installer..." \
        sudo -u "$INVOKER" bash -lc 'set -euo pipefail; curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n'
    run_task "Refreshing Kitty launcher symlink..." \
        sudo -u "$INVOKER" bash -lc 'mkdir -p ~/.local/bin && ln -sf ~/.local/kitty.app/bin/kitty ~/.local/bin/kitty'
    run_task "Registering Kitty with update-alternatives..." \
        update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$kitty_link" 50
    run_task "Setting Kitty as default terminal..." \
        update-alternatives --set x-terminal-emulator "$kitty_link"
}

# ---------- Main ----------
main() {
    printf '\n'
    log "Plan"
    printf '  • APT:       %s\n' "$S_OK"
    printf '  • Snap:      %s\n' "$([[ $DO_SNAP -eq 1 ]] && echo 'enabled' || echo 'skipped')"
    printf '  • Flatpak:   %s\n' "$([[ $DO_FLATPAK -eq 1 ]] && echo 'enabled' || echo 'skipped')"
    printf '  • Firmware:  %s\n' "$([[ $DO_FW -eq 1 ]] && echo 'enabled' || echo 'skipped')"
    printf '  • Clean:     %s\n' "$([[ $DO_CLEAN -eq 1 ]] && echo 'enabled' || echo 'skipped')"
    hr

    # Wait for dpkg lock if busy
    if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
        warn "dpkg is busy. Waiting up to 60s..."
        if ! timeout 60 bash -c 'while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done'; then
            warn "dpkg remained locked. Continuing; APT may fail."
        fi
    fi

    # --- APT ---
    section "APT (packages)"
    run_task "Updating package lists..." apt-get "${APT_OPTS_COMMON[@]}" update
    if ((FIX_BROKEN)); then
        run_task "Fixing broken installs..." apt-get "${APT_OPTS_COMMON[@]}" install -f -y
    fi
    run_task "Upgrading system packages..." apt-get "${APT_OPTS_PROGRESS[@]}" full-upgrade "${APT_Y[@]}" "${APT_DRY[@]}"

    if ((DO_CLEAN)); then
        run_task "Removing unused packages..." apt-get "${APT_OPTS_COMMON[@]}" autoremove --purge -y
        run_task "Cleaning APT cache..." apt-get "${APT_OPTS_COMMON[@]}" clean
    fi

    update_kitty

    # --- Snap ---
    if ((DO_SNAP)); then
        if have snap; then
            section "Snap"
            run_task "Listing Snap updates (if any)..." bash -c 'snap refresh --list || true'
            run_task "Refreshing Snap packages..." snap refresh
        else
            warn "snap not found; skipping Snap updates."
        fi
    fi

    # --- Flatpak ---
    if ((DO_FLATPAK)); then
        if have flatpak; then
            section "Flatpak"
            run_task "Updating system Flatpaks..." flatpak update --system --noninteractive -y
            if [[ -n "${INVOKER:-}" && -n "${INV_HOME:-}" ]]; then
                local uid
                uid=$(id -u "$INVOKER" 2>/dev/null || echo 0)
                if sudo -u "$INVOKER" XDG_RUNTIME_DIR=/run/user/"$uid" flatpak list --user | grep -q .; then
                    run_task "Updating user Flatpaks..." sudo -u "$INVOKER" XDG_RUNTIME_DIR=/run/user/"$uid" flatpak update --user --noninteractive -y
                else
                    printf "No user Flatpaks found for %s.\n" "$INVOKER"
                fi
            fi
        else
            warn "flatpak not found; skipping Flatpak updates."
        fi
    fi

    # --- Firmware ---
    if ((DO_FW)); then
        if have fwupdmgr; then
            section "Firmware (fwupdmgr)"
            run_task "Refreshing firmware sources..." fwupdmgr refresh --force
            if fwupdmgr get-updates | grep -q "No upgrades"; then
                printf "No firmware upgrades available.\n"
            else
                run_task "Applying firmware updates..." fwupdmgr update -y
            fi
        else
            warn "fwupdmgr not found. Install with: sudo apt install fwupd"
        fi
    fi

    # --- Final checks ---
    section "Final health checks"
    run_task "Ensuring packages are configured..." dpkg --configure -a
    run_task "Final dependency check..." apt-get "${APT_OPTS_COMMON[@]}" install -f -y

    # --- Wrap up ---
    section "Done"
    printf '%s Log saved to: %s\n' "$S_OK" "$LOG_FILE"

    if [[ -f /var/run/reboot-required ]]; then
        warn "Reboot is required to apply some updates."
        if ((DO_REBOOT)); then
            log "Rebooting now (--reboot requested)..."
            reboot
        else
            warn "To reboot, run: sudo reboot"
        fi
    elif ((DO_REBOOT)); then
        log "No reboot required, but rebooting as requested (--reboot)..."
        reboot
    fi
}

cleanup() { printf '\n%s Script finished.\n' "$S_INFO"; }
trap cleanup EXIT

main
