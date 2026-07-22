#!/usr/bin/env bash
set -euo pipefail

PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:${PATH}"

default_config="${HOME}/.config/kanata/colemak-dh-kanata-test.kbd"
legacy_config="${HOME}/.config/kanata/colemak-dh-ansi.kbd"
switcher="${HOME}/.local/bin/switch_layout.sh"
state_file="${HOME}/.current_xkb_layout"
guard_pid_file="${XDG_RUNTIME_DIR:-/tmp}/kanata-${UID}.guard.pid"
mode="toggle"
raw_keyboards=(
    "at-translated-set-2-keyboard"
    "asup1415:00-093a:300c-keyboard"
)

set_raw_keyboards_enabled() {
    local enabled="$1"
    local device

    command -v hyprctl >/dev/null 2>&1 || return 0
    for device in "${raw_keyboards[@]}"; do
        hyprctl keyword "device[${device}]:enabled" "${enabled}" >/dev/null 2>&1 || true
    done
}

kanata_device_is_available() {
    command -v hyprctl >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1
    hyprctl devices -j 2>/dev/null \
        | jq -e '.keyboards[] | select(.name == "kanata")' >/dev/null
}

# Supervise Kanata in a detached process. Raw keyboards are exposed while the
# virtual device is unavailable, then isolated again after an automatic restart.
if [[ "${1:-}" == "--guard" ]]; then
    selected_config="${2:-}"
    [[ -n "${selected_config}" ]] || exit 2
    guard_kanata_bin="${KANATA_BIN:-$(command -v kanata)}"
    guard_child=""

    guard_cleanup() {
        trap - EXIT INT TERM HUP
        if [[ -n "${guard_child}" ]] && kill -0 "${guard_child}" 2>/dev/null; then
            kill "${guard_child}" 2>/dev/null || true
            wait "${guard_child}" 2>/dev/null || true
        fi
        if [[ -r "${guard_pid_file}" ]] && [[ "$(<"${guard_pid_file}")" == "$$" ]]; then
            rm -f "${guard_pid_file}"
        fi
        set_raw_keyboards_enabled true
    }

    trap guard_cleanup EXIT
    trap 'exit 0' INT TERM HUP
    printf '%s\n' "$$" >"${guard_pid_file}"

    while true; do
        "${guard_kanata_bin}" -c "${selected_config}" -q --no-wait &
        guard_child=$!

        for _ in {1..30}; do
            kill -0 "${guard_child}" 2>/dev/null || break
            if kanata_device_is_available; then
                set_raw_keyboards_enabled false
                break
            fi
            sleep 0.1
        done

        wait "${guard_child}" 2>/dev/null || true
        guard_child=""
        set_raw_keyboards_enabled true
        sleep 0.5
    done
fi

# Hyprland reapplies device settings on config reloads. Restore the runtime
# isolation without restarting Kanata or changing the selected layout.
if [[ "${1:-}" == "--sync-devices" ]]; then
    if pgrep -x kanata >/dev/null 2>&1 && kanata_device_is_available; then
        set_raw_keyboards_enabled false
    else
        set_raw_keyboards_enabled true
    fi
    exit 0
fi

notify() {
    local message="$1"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low -t 2500 "Keyboard Layout" "${message}"
    else
        printf '%s\n' "${message}"
    fi
}

case "${1:-}" in
--ensure | --ensure-on | --force-on | --default | --current | --test)
    mode="default"
    shift
    ;;
--legacy | --previous | --stable)
    mode="legacy"
    shift
    ;;
--toggle | "")
    if [[ -n "${1:-}" ]]; then
        shift
    fi
    ;;
--help)
    cat <<'USAGE'
Usage: kanata_up.sh [--toggle|--ensure|--current|--legacy]

Without arguments the script toggles between the default Kanata layout and
the fallback plain US International layout.

  --ensure, --current  Activate the default Kanata-owned layout with US XKB.
  --legacy, --previous Activate the previous Kanata + CDHWIC configuration.
  --test               Alias for --current, retained for compatibility.
  --toggle             Toggle the default layout and plain US fallback.
USAGE
    exit 0
    ;;
*)
    echo "Unknown option: ${1}" >&2
    exit 1
    ;;
esac

if [[ $# -gt 0 ]]; then
    echo "Unexpected argument: ${1}" >&2
    exit 1
fi

kanata_bin="${KANATA_BIN:-}"
if [[ -z "${kanata_bin}" ]]; then
    if kanata_candidate="$(command -v kanata 2>/dev/null)" && [[ -n "${kanata_candidate}" ]]; then
        kanata_bin="${kanata_candidate}"
    elif [[ -x "${HOME}/.cargo/bin/kanata" ]]; then
        kanata_bin="${HOME}/.cargo/bin/kanata"
    elif [[ -x "${HOME}/.local/bin/kanata" ]]; then
        kanata_bin="${HOME}/.local/bin/kanata"
    else
        echo "Unable to locate kanata executable. Set KANATA_BIN or add kanata to PATH." >&2
        exit 1
    fi
fi

kanata_name="$(basename "${kanata_bin}")"

if [[ ! -x "${switcher}" ]]; then
    echo "Switch layout helper not executable: ${switcher}" >&2
    exit 1
fi

prepare_uinput() {
    if [[ ! -e /dev/uinput ]]; then
        echo "/dev/uinput not found." >&2
        exit 1
    fi

    if [[ -w /dev/uinput ]]; then
        return
    fi

    sudo chgrp uinput /dev/uinput
    sudo chmod 660 /dev/uinput
}

kanata_is_running() {
    pgrep -x "${kanata_name}" >/dev/null 2>&1
}

kanata_uses_config() {
    local expected="$1"
    local pid

    while read -r pid; do
        [[ -n "${pid}" ]] || continue
        if tr '\0' '\n' <"/proc/${pid}/cmdline" 2>/dev/null | grep -Fxq "${expected}"; then
            return 0
        fi
    done < <(pgrep -x "${kanata_name}" 2>/dev/null || true)

    return 1
}

stop_kanata() {
    local guard_pid=""

    if [[ -r "${guard_pid_file}" ]]; then
        guard_pid="$(<"${guard_pid_file}")"
        if [[ "${guard_pid}" =~ ^[0-9]+$ ]] && kill -0 "${guard_pid}" 2>/dev/null; then
            kill "${guard_pid}" 2>/dev/null || true
        fi
    fi

    if ! kanata_is_running && [[ -z "${guard_pid}" ]]; then
        set_raw_keyboards_enabled true
        return
    fi

    echo "Stopping kanata..."
    pkill -x "${kanata_name}" || true
    for _ in {1..20}; do
        if ! kanata_is_running \
            && { [[ -z "${guard_pid}" ]] || ! kill -0 "${guard_pid}" 2>/dev/null; }; then
            set_raw_keyboards_enabled true
            return 0
        fi
        sleep 0.05
    done

    echo "Kanata did not stop cleanly." >&2
    exit 1
}

validate_config() {
    local selected_config="$1"

    if [[ ! -f "${selected_config}" ]]; then
        echo "Kanata config not found: ${selected_config}" >&2
        exit 1
    fi

    "${kanata_bin}" --check -c "${selected_config}" >/dev/null
}

start_kanata() {
    local selected_config="$1"

    prepare_uinput
    echo "Starting kanata with $(basename "${selected_config}")..."
    if command -v setsid >/dev/null 2>&1; then
        setsid -f "$0" --guard "${selected_config}" >/dev/null 2>&1
    else
        nohup "$0" --guard "${selected_config}" >/dev/null 2>&1 &
    fi

    for _ in {1..30}; do
        kanata_uses_config "${selected_config}" && break
        sleep 0.1
    done
    if ! kanata_uses_config "${selected_config}"; then
        echo "Kanata failed to start with ${selected_config}." >&2
        exit 1
    fi

    # Do not expose the locked raw XKB devices while the remapped virtual
    # keyboard is active. Kanata reads evdev independently of Hyprland.
    for _ in {1..30}; do
        if kanata_device_is_available; then
            set_raw_keyboards_enabled false
            return
        fi
        sleep 0.1
    done

    stop_kanata
    echo "Kanata started but its virtual keyboard did not appear in Hyprland." >&2
    exit 1
}

activate_layout() {
    local selected_config="$1"
    local layout="$2"
    local message="$3"

    validate_config "${selected_config}"
    if ! kanata_uses_config "${selected_config}"; then
        stop_kanata
        "${switcher}" "${layout}"
        start_kanata "${selected_config}"
    else
        "${switcher}" "${layout}"
        set_raw_keyboards_enabled false
    fi
    notify "${message}"
}

current_state=""
if [[ -r "${state_file}" ]]; then
    current_state="$(tr -d '\r\n' <"${state_file}")"
fi

case "${mode}" in
default)
    activate_layout "${default_config}" kanata "Activated default Kanata layout."
    exit 0
    ;;
legacy)
    activate_layout "${legacy_config}" cdhwic "Activated previous Kanata + CDHWIC layout."
    exit 0
    ;;
esac

if [[ "${current_state}" == "kanata" || "${current_state}" == "kanata-test" || "${current_state}" == "cdhwic" ]]; then
    stop_kanata
    "${switcher}" intl
    notify "Switched to fallback plain US International layout."
    exit 0
fi

activate_layout "${default_config}" kanata "Activated default Kanata layout."
