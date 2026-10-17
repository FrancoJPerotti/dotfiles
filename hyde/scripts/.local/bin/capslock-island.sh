#!/usr/bin/env bash
set -euo pipefail

case "${1:---start}" in
--start)
    : "${HYPRLAND_INSTANCE_SIGNATURE:?Start this from a Hyprland session}"
    : "${WAYLAND_DISPLAY:?WAYLAND_DISPLAY is missing}"
    variables=(HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY)
    for variable in XDG_CURRENT_DESKTOP DISPLAY; do
        [[ -z "${!variable:-}" ]] || variables+=("${variable}")
    done
    systemctl --user import-environment "${variables[@]}"
    systemctl --user start capslock-island.service
    ;;
--stop)
    exec systemctl --user stop capslock-island.service
    ;;
--preview)
    exec "${HOME}/.local/bin/capslock-island.py" --preview
    ;;
*)
    printf 'Usage: %s [--start|--stop|--preview]\n' "${0##*/}" >&2
    exit 2
    ;;
esac
