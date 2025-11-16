#!/usr/bin/env bash
# i3_resize_truly_smart.sh - Final Correct Version
# This script applies the correct resize command based on
# the focused window's position on the screen.

direction="$1"
step="${2:-10}"

# Get the JSON for the focused window and its horizontal center (wx).
node_json=$(i3-msg -t get_tree | jq -r '.. | objects | select(.focused==true)')
wx=$(jq -r '.rect.x + (.rect.width / 2) | floor' <<<"$node_json")

# Find the active monitor the window is on and get its horizontal center (mx).
mx=$(
    i3-msg -t get_outputs | jq -r --argjson wx "$wx" '
  .[] | select(.active == true and $wx >= .rect.x and $wx < (.rect.x + .rect.width))
  | .rect.x + (.rect.width / 2) | floor' | head -n 1
)

# This block is the core logic that fixes the problem.
case "$direction" in
left)
    # Goal: Move the border to the LEFT.
    if ((wx > mx)); then
        # If the window is on the RIGHT, it must GROW to move the border left.
        i3-msg "resize grow width $step px or $step ppt"
    else
        # If the window is on the LEFT, it must SHRINK to move the border left.
        i3-msg "resize shrink width $step px or $step ppt"
    fi
    ;;
right)
    # Goal: Move the border to the RIGHT.
    if ((wx > mx)); then
        # If the window is on the RIGHT, it must SHRINK to move the border right.
        i3-msg "resize shrink width $step px or $step ppt"
    else
        # If the window is on the LEFT, it must GROW to move the border right.
        i3-msg "resize grow width $step px or $step ppt"
    fi
    ;;
up)
    # This logic can be extended for up/down if needed.
    i3-msg "resize shrink height $step px or $step ppt"
    ;;
down)
    # This logic can be extended for up/down if needed.
    i3-msg "resize grow height $step px or $step ppt"
    ;;
esac
