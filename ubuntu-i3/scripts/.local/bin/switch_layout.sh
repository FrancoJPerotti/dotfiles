#!/usr/bin/env bash
set -euo pipefail

state_file="${HOME}/.current_xkb_layout"
state=""
target="${1:-}"

if [[ -r "${state_file}" ]]; then
    state="$(tr -d '\r\n' < "${state_file}")"
fi

write_state() {
    printf '%s' "$1" > "${state_file}"
}

include_args=()
for dir in "${HOME}/.xkb" "${HOME}/dotfiles/xkb" "${HOME}/dotfiles/xkb/.xkb"; do
    if [[ -d "${dir}" ]]; then
        include_args+=(-I"${dir}")
    fi
done

# Ensure at least one include path so xkbcomp does not search only defaults
if [[ ${#include_args[@]} -eq 0 ]]; then
    include_args=(-I"${HOME}/.xkb")
fi

switch_to_us_intl() {
    echo "Switching to US International..."
    if setxkbmap us intl; then
        write_state "us-intl"
        return 0
    fi
    echo "setxkbmap failed" >&2
    return 1
}

switch_to_cdhwic() {
    echo "Switching to CDHWIC layout..."

    if [[ -n "${DISPLAY:-}" ]]; then
        if setxkbmap -layout cdhwic -variant cdhwic -print | xkbcomp "${include_args[@]}" - "${DISPLAY}"; then
            write_state "cdhwic"
            return 0
        fi
        echo "xkbcomp failed, trying setxkbmap fallback" >&2
        if setxkbmap -layout cdhwic -variant cdhwic; then
            write_state "cdhwic"
            return 0
        fi
        echo "setxkbmap fallback failed" >&2
        return 1
    fi

    echo "DISPLAY not set — using setxkbmap directly"
    if setxkbmap -layout cdhwic -variant cdhwic; then
        write_state "cdhwic"
        return 0
    fi
    echo "setxkbmap failed" >&2
    return 1
}

if [[ -n "${target}" ]]; then
    case "${target}" in
        cdhwic|custom)
            switch_to_cdhwic
            exit 0
            ;;
        us-intl|usintl|intl)
            switch_to_us_intl
            exit 0
            ;;
        *)
            echo "Unknown layout target: ${target}" >&2
            exit 1
            ;;
    esac
fi

if [[ "${state}" == "cdhwic" ]]; then
    switch_to_us_intl
else
    switch_to_cdhwic
fi
