#!/usr/bin/env bash
# Legacy reference only. Active startup lives in lua/autostart.lua.
set -euo pipefail

need() { command -v "$1" >/dev/null || {
    echo "❌ Missing: $1"
    exit 1
}; }
need hyprctl
need jq

# Hyprland 0.56+ interprets `hyprctl dispatch` as Lua. Quote the shell command
# as a Lua string and launch it through the native dispatcher instead.
hypr_exec() {
    local command="$1" quoted
    quoted=$(printf '%s' "$command" | jq -Rs '.')
    hyprctl eval "hl.dispatch(hl.dsp.exec_cmd(${quoted}))"
}

count_windows() {
    local ws="$1"
    hyprctl -j clients | jq --arg ws "$ws" \
        '[ .[] | select(.workspace.name == $ws) ] | length'
}

wait_for_workspace() {
    local ws="$1"
    for _ in {1..50}; do
        (($(count_windows "$ws") > 0)) && return
        sleep 0.1
    done
    echo "⚠️  Timed out waiting for workspace $ws; continuing."
}

launch_pwa() {
    local tag="$1" app="$2" ws="special:$1"
    echo "→ Starting $tag…"

    local before
    before=$(count_windows "$ws")

    # The Lua window rules move the PWA to ${ws} as soon as it is mapped.
    hypr_exec "/opt/vivaldi/vivaldi --app=${app}" &

    # Wait until the number of windows on that workspace increases
    for _ in {1..50}; do
        (($(count_windows "$ws") > before)) && {
            echo "   ↳ $tag ready."
            return
        }
        sleep 0.1
    done

    echo "❌ Timed out waiting for $tag window!"
    exit 1
}

###############################################################################
# PWAs
###############################################################################

launch_pwa spotify https://spotify.com
launch_pwa whatsapp https://web.whatsapp.com
# launch_pwa discord https://discord.com/app
launch_pwa ticktick https://ticktick.com
launch_pwa chatgpt https://chatgpt.com
# hypr_exec obsidian

###############################################################################
# Regular workspaces
###############################################################################

hypr_exec "kitty --class nvim --title nvim nvim" &
hypr_exec "kitty --class term" &
hypr_exec "kitty --class yazi --title yazi yazi" &
wait_for_workspace 2
wait_for_workspace 3
wait_for_workspace 4
hypr_exec vivaldi &
sleep 0.5 # give the main browser time to map before restoring workspace 1
hyprctl eval 'hl.dispatch(hl.dsp.focus({workspace = "1"}))'
