#!/usr/bin/env bash
set -euo pipefail

PATH="${HOME}/.cargo/bin:${HOME}/.local/bin:${PATH}"

config="${HOME}/.config/kanata/colemak-dh-ansi.kbd"
switcher="${HOME}/.local/bin/switch_layout.sh"
state_file="${HOME}/.current_xkb_layout"
mode="toggle"

notify() {
    local message="$1"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low -t 2500 "Keyboard Layout" "${message}"
    else
        printf '%s\n' "${message}"
    fi
}

case "${1:-}" in
--ensure | --ensure-on | --force-on)
    mode="ensure"
    shift
    ;;
--toggle | "")
    if [[ -n "${1:-}" ]]; then
        shift
    fi
    ;;
--help)
    cat <<'USAGE'
Usage: kanata_up.sh [--ensure]

Without arguments the script toggles between the custom Kanata layout and
the fallback US International layout. Pass --ensure to guarantee the custom
layout is active.
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

if [[ ! -f "${config}" ]]; then
    echo "Kanata config not found: ${config}" >&2
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

current_state=""
if [[ -r "${state_file}" ]]; then
    current_state="$(tr -d '\r\n' <"${state_file}")"
fi

kanata_running=0
if pgrep -x "${kanata_name}" >/dev/null 2>&1; then
    kanata_running=1
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

ensure_kanata_running() {
    if ((kanata_running)); then
        return
    fi

    prepare_uinput
    echo "Starting kanata..."
    nohup "${kanata_bin}" -c "${config}" -q >/dev/null 2>&1 &
    sleep 0.5
    kanata_running=1
}

if [[ "${mode}" == "ensure" ]]; then
    ensure_kanata_running
    "${switcher}" custom
    notify "Activated custom layout."
    exit 0
fi

if [[ "${current_state}" == "cdhwic" ]]; then
    if ((kanata_running)); then
        echo "Stopping kanata..."
        pkill -x "${kanata_name}" || true
    fi
    "${switcher}" intl
    notify "Switched to US International layout."
    exit 0
fi

ensure_kanata_running
"${switcher}" custom
notify "Activated custom layout."
