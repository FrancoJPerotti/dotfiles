#!/usr/bin/env bash
set -euo pipefail

ICON_PLAY=""
ICON_PAUSE=""
ICON_STOP=""
PLACEHOLDER="No music"

fmt_track() {
    local text="$1" max=60
    # Trim to max chars (rough but works fine for usual ASCII/latin glyphs)
    [ "${#text}" -gt "$max" ] && text="${text:0:max}…"
    printf "%s" "$text"
}

print_line() {
    # Try current metadata from any player
    if playerctl -a status >/dev/null 2>&1; then
        local status artist title icon
        status="$(playerctl -a status 2>/dev/null | head -n1 || true)"
        case "$status" in
        Playing) icon="$ICON_PLAY" ;;
        Paused) icon="$ICON_PAUSE" ;;
        Stopped | "") icon="$ICON_STOP" ;;
        *) icon="$ICON_STOP" ;;
        esac
        artist="$(playerctl -a metadata artist 2>/dev/null | head -n1 || true)"
        title="$(playerctl -a metadata title 2>/dev/null | head -n1 || true)"
        if [ -n "${artist}${title}" ]; then
            printf '%%{T1}%s%%{T-} %s\n' "$icon" "$(fmt_track "$artist - $title")"
            return
        fi
    fi
    # Fallback placeholder
    printf '%%{T1}%s%%{T-} %s\n' "$ICON_STOP" "$PLACEHOLDER"
}

# Print once immediately
print_line

# Then follow updates from any player (appearing/disappearing)
playerctl -a metadata -F -f '{{status}}|{{artist}} - {{title}}' 2>/dev/null | while IFS='|' read -r status text; do
    case "$status" in
    Playing) icon="$ICON_PLAY" ;;
    Paused) icon="$ICON_PAUSE" ;;
    *) icon="$ICON_STOP" ;;
    esac
    [ -z "$text" ] && text="$PLACEHOLDER"
    printf '%%{T1}%s%%{T-} %s\n' "$icon" "$(fmt_track "$text")"
done
