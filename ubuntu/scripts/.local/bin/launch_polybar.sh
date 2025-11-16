#!/usr/bin/env bash
set -euo pipefail

lockfile="${XDG_RUNTIME_DIR:-/tmp}/launch_polybar.lock"
exec 200>"$lockfile"
if ! flock -n 200; then
    exit 0
fi

internal_regex='^(eDP|LVDS|DSI)'
allow_internal_fallback="${POLYBAR_ALLOW_INTERNAL_FALLBACK:-1}"

connected_list=()
active_list=()
external_monitor=""
internal_monitor=""

refresh_monitor_state() {
    local query_output=""
    local monitors_output=""
    query_output="$(xrandr --query 2>/dev/null || true)"
    mapfile -t connected_list < <(printf '%s\n' "$query_output" | awk '/ connected/{print $1}')
    mapfile -t active_list < <(printf '%s\n' "$query_output" | awk '
        / connected/ {
            if ($0 ~ / [0-9]+x[0-9]+\+/) {
                print $1
            }
        }')
    if ((${#active_list[@]} == 0)); then
        monitors_output=$(xrandr --listmonitors 2>/dev/null || true)
        mapfile -t active_list < <(printf '%s\n' "$monitors_output" | awk 'NR>1 {print $NF}')
    fi
}

is_in_array() {
    local needle="$1"
    shift
    for item in "$@"; do
        if [[ "$item" == "$needle" ]]; then
            return 0
        fi
    done
    return 1
}

select_internal_monitor() {
    local desired="${POLYBAR_INTERNAL_MONITOR:-}"
    if [[ -n "$desired" ]]; then
        if is_in_array "$desired" "${active_list[@]}"; then
            printf '%s' "$desired"
            return
        fi
    fi

    for monitor in "${active_list[@]}"; do
        if [[ "$monitor" =~ $internal_regex ]]; then
            printf '%s' "$monitor"
            return
        fi
    done
}

select_external_monitor() {
    local desired="${POLYBAR_EXTERNAL_MONITOR:-}"
    if [[ -n "$desired" ]] && is_in_array "$desired" "${active_list[@]}"; then
        printf '%s' "$desired"
        return
    fi

    for monitor in "${active_list[@]}"; do
        if [[ ! "$monitor" =~ $internal_regex ]]; then
            printf '%s' "$monitor"
            return
        fi
    done
}

connected_external_present() {
    for monitor in "${connected_list[@]}"; do
        if [[ ! "$monitor" =~ $internal_regex ]]; then
            return 0
        fi
    done
    return 1
}

stop_polybar() {
    killall -q polybar 2>/dev/null || true
    while pgrep -x polybar >/dev/null; do
        sleep 1
    done
}

refresh_monitor_state

external_monitor="$(select_external_monitor)"

if connected_external_present && [[ -z "$external_monitor" ]]; then
    if [[ "$allow_internal_fallback" != "1" ]]; then
        stop_polybar
        exit 0
    fi
fi

external_monitor="${external_monitor:-}"
internal_monitor="$(select_internal_monitor)"
target_monitor="${external_monitor:-$internal_monitor}"

stop_polybar

if [[ -n "$target_monitor" ]]; then
    MONITOR="$target_monitor" polybar --reload &
else
    polybar --reload &
fi
