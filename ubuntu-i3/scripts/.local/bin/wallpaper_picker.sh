#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/.local/share/wallpapers"
CURRENT_WALLPAPER="$WALL_DIR/current_wallpaper"
CURRENT_LOCK_WALLPAPER="$WALL_DIR/current_lock_wallpaper"
APPLY_WALL_SCRIPT="$HOME/.local/bin/apply_wallpaper.sh"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-picker"
THUMB_DIR="$CACHE_DIR/thumbs"
THUMB_WIDTH=320
THUMB_HEIGHT=180

mkdir -p "$WALL_DIR" "$THUMB_DIR"

# ---------------- helpers ----------------
have() { command -v "$1" >/dev/null 2>&1; }

sanitize_for_path() {
  local name="${1//[^A-Za-z0-9._-]/_}"
  echo "$name"
}

ensure_thumbnail() {
  local src="$1"
  local base sanitized dst
  base="$(basename "$src")"
  sanitized="$(sanitize_for_path "$base")"
  dst="$THUMB_DIR/${sanitized}.png"

  if [[ -f "$dst" && "$dst" -nt "$src" ]]; then
    echo "$dst"
    return 0
  fi

  if ! have convert; then
    return 1
  fi

  if convert "$src" \
    -auto-orient \
    -strip \
    -resize "${THUMB_WIDTH}x${THUMB_HEIGHT}^" \
    -gravity center -extent "${THUMB_WIDTH}x${THUMB_HEIGHT}" \
    "PNG:$dst" >/dev/null 2>&1; then
    echo "$dst"
    return 0
  fi

  return 1
}

apply_wallpaper() {
  local image="${1:-}"
  [[ -z "$image" ]] && return 0

  if [[ -x "$APPLY_WALL_SCRIPT" ]]; then
    "$APPLY_WALL_SCRIPT" "$image"
    return 0
  fi

  if have feh; then
    feh --bg-fill "$image" >/dev/null 2>&1 &
  fi
}

# -------------- gather images --------------
mapfile -t files < <(
  find -L "$WALL_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) \
    -printf '%f\n' | sort -V
)

# Exit silently if no wallpapers
[[ ${#files[@]} -eq 0 ]] && exit 0

declare -a entries=()
use_icons=false
for filename in "${files[@]}"; do
  thumb=""
  if thumb_path="$(ensure_thumbnail "$WALL_DIR/$filename" 2>/dev/null)"; then
    thumb="$thumb_path"
  fi
  if [[ -n "${thumb:-}" ]]; then
    entries+=("ICON:$thumb")
    use_icons=true
  else
    entries+=("TEXT:$filename")
  fi
done

ICON_THEME=$'window { width: 50em; height: 20em; }\ntextbox-prompt-colon { enabled: false; }\nmainbox { children: [listview]; padding: 1em; spacing: 0px; }\nlistview { columns: 3; lines: 1; spacing: 0em; cycle: false; dynamic: false; }\nscrollbar { enabled: false; }\nelement { orientation: vertical; children: [element-icon]; padding: 0.75em; border-radius: 18px; border: 3px; border-color: transparent; background-color: transparent; }\nelement selected { border-color: @selected; background-color: rgba(255,255,255,0.05); }\nelement-icon { size: 16em; border-radius: 18px; margin: 0px; }'
TEXT_THEME=$'listview { lines: 10; }\nelement { padding: 10px; }'

if [[ "$use_icons" == true ]]; then
  ROFI_THEME_STR="$ICON_THEME"
  ROFI_BASE=(rofi -dmenu -i -markup-rows -p "" -format i -theme-str "$ROFI_THEME_STR" -location 2 -show-icons)
else
  ROFI_THEME_STR="$TEXT_THEME"
  ROFI_BASE=(rofi -dmenu -i -markup-rows -p "" -format i -theme-str "$ROFI_THEME_STR" -location 2 -no-show-icons)
fi

# -------------- pick with rofi --------------
choice_index="$(
  {
    for entry in "${entries[@]}"; do
      if [[ "$entry" == ICON:* ]]; then
        thumb="${entry#ICON:}"
        printf ' \0icon\x1f%s\0display\x1f \n' "$thumb"
      else
        text="${entry#TEXT:}"
        printf '%s\n' "$text"
      fi
    done
  } | "${ROFI_BASE[@]}"
)"
[[ -z "${choice_index:-}" || "$choice_index" == "-1" ]] && exit 0

if [[ "$choice_index" =~ ^[0-9]+$ ]] && ((choice_index < ${#files[@]})); then
  choice="${files[choice_index]}"
else
  choice="$choice_index"
fi

src="$WALL_DIR/$choice"
base="${choice%.*}"

# Apply immediately so the selection feels instant; heavy work happens later.
apply_wallpaper "$src"

# Normalize and copy assets asynchronously so the picker stays responsive.
(
  set -euo pipefail
  trap '[[ -n "${tmp_copy:-}" ]] && rm -f -- "${tmp_copy}"' EXIT

  tmp_copy=""
  processed="$src"

  if have convert; then
    tmp_copy="$(mktemp "${WALL_DIR}/.tmp_${base}.XXXXXX.png")"
    if convert "$src" -auto-orient -strip "PNG:$tmp_copy" >/dev/null 2>&1; then
      mv -f -- "$tmp_copy" "$CURRENT_WALLPAPER"
      tmp_copy=""
      processed="$CURRENT_WALLPAPER"
    else
      rm -f -- "$tmp_copy"
      tmp_copy=""
      cp -f -- "$processed" "$CURRENT_WALLPAPER"
    fi
  else
    cp -f -- "$processed" "$CURRENT_WALLPAPER"
  fi

  if have convert; then
    convert "$CURRENT_WALLPAPER" \
      -resize 50% -blur 0x8 -resize 200% \
      -strip -define png:compression-level=3 -define png:compression-strategy=1 \
      "PNG:$CURRENT_LOCK_WALLPAPER" >/dev/null 2>&1 || true
  else
    cp -f -- "$CURRENT_WALLPAPER" "$CURRENT_LOCK_WALLPAPER"
  fi

  apply_wallpaper "$CURRENT_WALLPAPER"
) >/dev/null 2>&1 &

exit 0
