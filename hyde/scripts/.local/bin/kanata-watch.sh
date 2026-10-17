#!/usr/bin/env bash
set -euo pipefail

service="kanata-keyboard-watch.service"
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=kanata-keyboard-policy.sh
source "${script_dir}/kanata-keyboard-policy.sh"
controller="${HOME}/.local/bin/kanata_up.sh"

case "${1:---watch}" in
--start)
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || {
        echo "The keyboard watcher must be started from a Hyprland session." >&2
        exit 1
    }
    session_vars=(HYPRLAND_INSTANCE_SIGNATURE)
    for variable in WAYLAND_DISPLAY XDG_CURRENT_DESKTOP; do
        [[ -z "${!variable:-}" ]] || session_vars+=("${variable}")
    done
    systemctl --user import-environment "${session_vars[@]}"
    systemctl --user daemon-reload
    # start is idempotent; a config reload keeps the existing listener.
    systemctl --user start "${service}"
    exit 0
    ;;
--stop)
    exec systemctl --user stop "${service}"
    ;;
--watch) ;;
*) echo "Usage: kanata-watch.sh [--start|--stop|--watch]" >&2; exit 2 ;;
esac

previous=""
reconcile() {
    local attached=0 status=0 mode state=""
    firmware_keyboard_connected || status=$?
    case "${status}" in
    0) attached=1 ;;
    1) attached=0 ;;
    *) echo "Cannot read input devices; preserving keyboard state." >&2; return 0 ;;
    esac
    [[ "${attached}" != "${previous}" ]] || return 0
    if [[ "${attached}" == 1 ]]; then
        mode=--sync-devices
    elif [[ -n "${previous}" ]]; then
        mode=--ensure
    else
        # Recover a remapper stopped by a service restart, while keeping a
        # user-selected plain layout off. The firmware marker also survives.
        [[ ! -r "${HOME}/.current_xkb_layout" ]] || state=$(<"${HOME}/.current_xkb_layout")
        case "${state}" in
        kanata | kanata-test) mode=--ensure ;;
        cdhwic) mode=--legacy ;;
        *) mode=--sync-devices ;;
        esac
    fi
    if "${controller}" "${mode}"; then
        previous="${attached}"
    else
        echo "Failed to update Kanata; the next device event will retry." >&2
    fi
}

# The read below blocks until udev sends data: no periodic timer or scan.
coproc KANATA_EVENTS { exec stdbuf -oL udevadm monitor --udev --subsystem-match=input; }
monitor_pid=${KANATA_EVENTS_PID}
exec {event_fd}<&"${KANATA_EVENTS[0]}"
monitor_write_fd=${KANATA_EVENTS[1]}
exec {monitor_write_fd}>&-
cleanup() {
    trap - EXIT INT TERM HUP
    kill "${monitor_pid}" 2>/dev/null || true
    wait "${monitor_pid}" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' INT TERM HUP

# udevadm's banner follows subscription. A hotplug during startup is either
# included in this initial scan or queued in the monitor's event stream.
while IFS= read -r -u "${event_fd}" line; do
    if [[ "${line}" == "UDEV -"* ]]; then
        reconcile
    elif [[ "${line}" =~ ^UDEV[[:space:]]+\[ ]]; then
        reconcile
    fi
done
echo "udevadm monitor exited unexpectedly." >&2
exit 1
