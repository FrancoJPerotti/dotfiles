#!/usr/bin/env bash
set -euo pipefail

state_file="${HOME}/.current_xkb_layout"
target="${1:-}"

need() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing dependency: $1" >&2
        exit 1
    }
}

write_state() {
    printf '%s' "$1" >"${state_file}"
}

current_state() {
    if [[ -r "${state_file}" ]]; then
        tr -d '\r\n' <"${state_file}"
    fi
}

set_layout_index() {
    local index="$1"
    hyprctl switchxkblayout all "${index}" >/dev/null
}

switch_to_us_intl() {
    echo "Switching to US International..."
    set_layout_index 0
    write_state "us-intl"
}

switch_to_cdhwic() {
    echo "Switching to CDHWIC layout..."
    set_layout_index 1
    write_state "cdhwic"
}

need hyprctl

case "${target}" in
custom | cdhwic)
    switch_to_cdhwic
    exit 0
    ;;
us-intl | usintl | intl)
    switch_to_us_intl
    exit 0
    ;;
"")
    ;;
*)
    echo "Unknown layout target: ${target}" >&2
    exit 1
    ;;
esac

if [[ "$(current_state)" == "cdhwic" ]]; then
    switch_to_us_intl
else
    switch_to_cdhwic
fi
