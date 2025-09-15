#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/.local/share/wallpapers"
CURRENT_WALLPAPER="$WALL_DIR/current_wallpaper"
CURRENT_LOCK_WALLPAPER="$WALL_DIR/current_lock_wallpaper"

mkdir -p "$WALL_DIR"

# ---------------- helpers ----------------
have() { command -v "$1" >/dev/null 2>&1; }

get_primary_resolution() {
  # Prefer primary output
  if have xrandr; then
    if xrandr | grep -q " connected primary "; then
      # Field with resolution like 1920x1080+X+Y
      xrandr | awk '/ connected primary /{print $4}' | sed 's/+.*//; s/x/ /'
      return
    fi
    # Fallback: first mode marked with '*'
    local mode
    mode="$(xrandr --current | awk '/\*/{print $1; exit}')"
    if [[ -n "${mode:-}" ]]; then
      echo "$mode" | sed 's/x/ /'
      return
    fi
  fi
  # X11 fallback
  if have xdpyinfo; then
    xdpyinfo | awk '/dimensions:/{print $2}' | sed 's/x/ /'
    return
  fi
  # Last resort
  echo "1920 1080"
}

resize_crop_to() {
  # $1: src, $2: WxH, $3: dst
  local src="$1" size="$2" dst="$3"
  convert "$src" \
    -filter Lanczos -resize "${size}^" -gravity center -extent "$size" \
    -strip -define png:compression-level=3 -define png:compression-strategy=1 \
    "$dst"
}

# -------------- gather images --------------
mapfile -t files < <(
  find -L "$WALL_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \) \
    -printf '%f\n' | sort -V
)

# Exit silently if no wallpapers
[[ ${#files[@]} -eq 0 ]] && exit 0

ROFI_BASE=(rofi -dmenu -i -markup-rows -p "wallpaper"
  -show-icons false
  -theme-str ' element { padding: 6px; }
               element-icon { size: 0; }'
)

# -------------- pick with rofi --------------
choice="$(printf '%s\n' "${files[@]}" | "${ROFI_BASE[@]}")"
[[ -z "${choice:-}" ]] && exit 0

src="$WALL_DIR/$choice"
base="${choice%.*}"
png_src="$WALL_DIR/${base}.png"

# -------------- target size --------------
read -r W H <<<"$(get_primary_resolution)"
TARGET="${W}x${H}"

# -------------- fast path (already PNG & right size) --------------
if [[ "${choice,,}" == *.png ]] && have identify; then
  if [[ "$(identify -format '%wx%h' "$src" 2>/dev/null || echo '')" == "$TARGET" ]]; then
    # Already perfect: just copy/apply and blur in background
    cp -f -- "$src" "$CURRENT_WALLPAPER"
    (
      convert "$src" -resize 50% -blur 0x8 -resize 200% \
        -strip -define png:compression-level=3 -define png:compression-strategy=1 \
        "$CURRENT_LOCK_WALLPAPER"
    ) >/dev/null 2>&1 &
    have feh && feh --bg-fill "$CURRENT_WALLPAPER" >/dev/null 2>&1 &
    exit 0
  fi
fi

# -------------- convert, resize, and REPLACE original --------------
tmp_resized="$(mktemp "${WALL_DIR}/.tmp_${base}_${W}x${H}.XXXXXX.png")"
resize_crop_to "$src" "$TARGET" "$tmp_resized"

# Move resized PNG into place as the new original
mv -f -- "$tmp_resized" "$png_src"

# Remove old file if its name differs (e.g., .jpg/.webp)
if [[ "$src" != "$png_src" ]]; then
  rm -f -- "$src"
fi

# -------------- update current files --------------
cp -f -- "$png_src" "$CURRENT_WALLPAPER"

# Lock image (async & quick)
(
  convert "$png_src" \
    -resize 50% -blur 0x8 -resize 200% \
    -strip -define png:compression-level=3 -define png:compression-strategy=1 \
    "$CURRENT_LOCK_WALLPAPER"
) >/dev/null 2>&1 &

# -------------- apply immediately --------------
if have feh; then
  feh --bg-fill "$CURRENT_WALLPAPER" >/dev/null 2>&1 &
fi

exit 0
