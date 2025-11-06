#!/usr/bin/env bash
set -euo pipefail

WALLPAPER="${1:-$HOME/.local/share/wallpapers/current_wallpaper}"

if [[ ! -f "$WALLPAPER" ]]; then
  exit 0
fi

have() { command -v "$1" >/dev/null 2>&1; }

if ! have feh; then
  exit 0
fi

declare -a outputs=()
if have xrandr; then
  mapfile -t outputs < <(xrandr --query 2>/dev/null | awk '/ connected/{print $1}' || true)
fi

declare -a files=()
if ((${#outputs[@]} > 1)); then
  for _ in "${outputs[@]}"; do
    files+=("$WALLPAPER")
  done
fi

if ((${#files[@]} == 0)); then
  files=("$WALLPAPER")
fi

mode="${FEH_WALL_MODE:-fill}"
declare -a feh_cmd=("feh")
case "$mode" in
  fill) feh_cmd+=("--bg-fill") ;;
  max) feh_cmd+=("--bg-max") ;;
  scale) feh_cmd+=("--bg-scale") ;;
  center) feh_cmd+=("--bg-center") ;;
  tile) feh_cmd+=("--bg-tile") ;;
  *) feh_cmd+=("--bg-fill") ;;
esac

if [[ -n "${FEH_BG_COLOR:-}" ]]; then
  feh_cmd+=("--image-bg" "$FEH_BG_COLOR")
fi

"${feh_cmd[@]}" "${files[@]}" >/dev/null 2>&1 &

exit 0
