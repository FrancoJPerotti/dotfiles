#!/bin/bash

# Get the active window info
active_window=$(hyprctl activewindow)

# Check if the active workspace is a scratchpad (special workspace)
if echo "$active_window" | grep -q "special:"; then
    # Extract the special workspace name using grep with Perl regex
    special_name=$(echo "$active_window" | grep -oP 'special:\K[^\)]+')
    echo "Toggling special workspace: $special_name"
    hyprctl dispatch togglespecialworkspace "$special_name"
else
    echo "No special workspace is active."
fi
