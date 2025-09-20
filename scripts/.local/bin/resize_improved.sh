#!/usr/bin/env bash
# i3_resize_directional.sh
# A script that moves window borders in an absolute direction,
# regardless of which window is focused.

direction="$1"
step="${2:-10}"

# Get the JSON of the focused window
node_json=$(i3-msg -t get_tree | jq -rc '.. | objects | select(.focused==true)')
[[ -n "$node_json" ]] || exit 0

# If window is floating, the directions are simpler
if [[ "$(jq -r '.floating' <<<"$node_json")" == "user_on" ]]; then
    case "$direction" in
    left) i3-msg "resize shrink width $step px or $step ppt" ;;
    right) i3-msg "resize grow width $step px or $step ppt" ;;
    up) i3-msg "resize shrink height $step px or $step ppt" ;;
    down) i3-msg "resize grow height $step px or $step ppt" ;;
    esac
    exit 0
fi

# Get the coordinates of the focused window's center
read -r wx wy <<<"$(jq -r '.rect.x + (.rect.width / 2) | floor, .rect.y + (.rect.height / 2) | floor' <<<"$node_json")"

# Find the monitor that the window is on and get its center coordinates
read -r mx my <<<"$(
    i3-msg -t get_outputs | jq -r --argjson wx "$wx" --argjson wy "$wy" '
  .[] | select(.active==true and $wx >= .rect.x and $wx < (.rect.x + .rect.width))
  | .rect.x + (.rect.width / 2) | floor, .rect.y + (.rect.height / 2) | floor' | head -n 1
)"

# This is the core logic, based on your correct analysis.
case "$direction" in
left)
    if ((wx > mx)); then
        # Focused window is on the RIGHT. To move the border left, this window must GROW.
        i3-msg "resize grow width $step px or $step ppt"
    else
        # Focused window is on the LEFT. To move the border left, this window must SHRINK.
        i3-msg "resize shrink width $step px or $step ppt"
    fi
    ;;
right)
    if ((wx > mx)); then
        # Focused window is on the RIGHT. To move the border right, this window must SHRINK.
        i3-msg "resize shrink width $step px or $step ppt"
    else
        # Focused window is on the LEFT. To move the border right, this window must GROW.
        i3-msg "resize grow width $step px or $step ppt"
    fi
    ;;
up)
    if ((wy > my)); then
        # Focused window is on the BOTTOM. To move the border up, this window must GROW.
        i3-msg "resize grow height $step px or $step ppt"
    else
        # Focused window is on the TOP. To move the border up, this window must SHRINK.
        i3-msg "resize shrink height $step px or $step ppt"
    fi
    ;;
down)
    if ((wy > my)); then
        # Focused window is on the BOTTOM. To move the border down, this window must SHRINK.
        i3-msg "resize shrink height $step px or $step ppt"
    else
        # Focused window is on the TOP. To move the border down, this window must GROW.
        i3-msg "resize grow height $step px or $step ppt"
    fi
    ;;
esac
