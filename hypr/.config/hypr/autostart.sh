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
    local tag="$1" appid="$2" ws="special:$1"
    echo "→ Starting $tag…"

    local before
    before=$(count_windows "$ws")

    hyprctl dispatch exec "[workspace ${ws} silent] \
      /opt/vivaldi/vivaldi --profile-directory=Default --app-id=${appid}" &

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

launch_pwa spotify pjibgclleladliembfgfagdaldikeohf
launch_pwa whatsapp hnpfjngllnobngcgfapefoaidbinmjnm
launch_pwa discord mfhpbolkhgobaabcbabdlnhidbjpoogc
launch_pwa ticktick cfammbeebmjdpoppachopcohfchgjapd
launch_pwa chatgpt cadlkienfkclaiaibeoongdcgmdikeeg

###############################################################################
# Regular workspaces
###############################################################################

hyprctl dispatch workspace 2
hyprctl dispatch exec "kitty nvim" &
hyprctl dispatch workspace 3
hyprctl dispatch exec kitty &
hyprctl dispatch workspace 4
hyprctl dispatch exec kitty yazi &
hyprctl dispatch workspace 1
hyprctl dispatch exec vivaldi &
