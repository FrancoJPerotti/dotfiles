#!/usr/bin/env bash
set -euo pipefail

need() { command -v "$1" >/dev/null || {
    echo "❌ Missing: $1"
    exit 1
}; }
need hyprctl
need jq

count_windows() {
    local ws="$1"
    hyprctl -j clients | jq --arg ws "$ws" \
        '[ .[] | select(.workspace.name == $ws) ] | length'
}

launch_pwa() {
    local tag="$1" app="$2" ws="special:$1"
    echo "→ Starting $tag…"

    local before
    before=$(count_windows "$ws")

    hyprctl dispatch exec "[workspace ${ws} silent] \
      /opt/vivaldi/vivaldi --app=${app}" &

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
launch_pwa discord https://discord.com/app
launch_pwa ticktick https://ticktick.com
launch_pwa chatgpt https://chatgpt.com
hyprctl dispatch exec obsidian

###############################################################################
# Regular workspaces
###############################################################################

hyprctl dispatch exec "kitty --class nvim --title nvim nvim" &
hyprctl dispatch exec "kitty --class term" &
hyprctl dispatch exec "kitty --class yazi --title yazi yazi" &
sleep 1 # give windows time to launch and move to their assigned workspaces
hyprctl dispatch workspace 1
hyprctl dispatch exec vivaldi &
