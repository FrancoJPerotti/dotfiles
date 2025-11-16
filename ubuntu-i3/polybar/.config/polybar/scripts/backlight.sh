#!/usr/bin/env bash

set -euo pipefail

ICON=""
ICON_COLOR="#FF79C6"

print_brightness() {
  local current max percentage
  current=$1
  max=$2

  if [[ "$max" -gt 0 ]]; then
    # Integer percentage calculation
    percentage=$(( current * 100 / max ))
    printf "%%{F%s}%s%%{F-} %d%%\n" "$ICON_COLOR" "$ICON" "$percentage"
    exit 0
  fi
}

# Try using brightnessctl if available
if command -v brightnessctl >/dev/null 2>&1; then
  if current=$(brightnessctl get 2>/dev/null) && \
     max=$(brightnessctl max 2>/dev/null); then
    print_brightness "$current" "$max"
  fi
fi

# Fallback to raw sysfs entries
shopt -s nullglob
for entry in /sys/class/backlight/*; do
  [[ -d "$entry" ]] || continue

  brightness_file="$entry/brightness"
  max_brightness_file="$entry/max_brightness"

  if [[ -r "$brightness_file" && -r "$max_brightness_file" ]]; then
    current=$(<"$brightness_file")
    max=$(<"$max_brightness_file")
    print_brightness "$current" "$max"
  fi
done
shopt -u nullglob

# Nothing to display when no backlight is present
exit 0
