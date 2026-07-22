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

set_layout() {
    local layout="$1"
    local variant="${2:-}"

    if [[ -n "${variant}" ]]; then
        hyprctl keyword input:kb_layout "${layout}" >/dev/null
        hyprctl keyword input:kb_variant "${variant}" >/dev/null
        return
    fi

    hyprctl keyword input:kb_variant "" >/dev/null
    hyprctl keyword input:kb_layout "${layout}" >/dev/null
}

switch_to_us() {
    local state="${1:-us}"
    local variant="${2:-}"
    local label="US"
    if [[ -n "${variant}" ]]; then
        label="US ${variant}"
    fi
    echo "Switching to ${label} layout..."
    set_layout us "${variant}"
    write_state "${state}"
}

switch_to_cdhwic() {
    echo "Switching to CDHWIC layout..."
    set_layout cdhwic
    write_state "cdhwic"
}

need hyprctl

case "${target}" in
legacy | previous | custom | cdhwic)
    switch_to_cdhwic
    exit 0
    ;;
us-intl | usintl | intl)
    switch_to_us "us-intl" intl
    exit 0
    ;;
kanata | default | kanata-test | test)
    switch_to_us "kanata" intl
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
    switch_to_us
else
    switch_to_cdhwic
fi
