#!/usr/bin/env bash

if [[ "$6" == "1" ]]; then
  set -x
fi

# Custom wrapper for xdg-desktop-portal-termfilechooser using yazi.
# Based on the upstream yazi-wrapper.sh, but adds --class yazi-selector
# so Hyprland window rules (float, size, center) can match it.

multiple="$1"
directory="$2"
save="$3"
path="$4"
out="$5"
cmd="/usr/bin/yazi"

if [ "$save" = "1" ]; then
  TITLE="Save File:"
elif [ "$directory" = "1" ]; then
  TITLE="Select Directory:"
else
  TITLE="Select File:"
fi

# Calculate kitty size from monitor resolution
monitor_json=$(hyprctl monitors -j 2>/dev/null)
if [ -n "$monitor_json" ]; then
  mon_w=$(echo "$monitor_json" | jq -r '.[0].width // 1920')
  mon_h=$(echo "$monitor_json" | jq -r '.[0].height // 1080')
  cols=$(( mon_w * 38 / 100 / 12 ))
  rows=$(( mon_h * 36 / 100 / 22 ))
else
  cols=120
  rows=35
fi

termcmd=(
  /usr/bin/env
  KITTY_DISABLE_WAYLAND=1
  /usr/bin/kitty
  --class yazi-selector
  --override font_size=18.0
  --override remember_window_size=no
  --override "initial_window_width=${cols}c"
  --override "initial_window_height=${rows}c"
  --title "$TITLE"
)
if [[ -n "${TERMCMD:-}" ]]; then
  read -r -a termcmd <<<"$TERMCMD"
fi

cleanup() {
  if [ -f "$tmpfile" ]; then
    /usr/bin/rm "$tmpfile" || :
  fi
  if [ "$save" = "1" ] && [ ! -s "$out" ]; then
    /usr/bin/rm "$path" || :
  fi
}

trap cleanup EXIT HUP INT QUIT ABRT TERM

if [ "$save" = "1" ]; then
  tmpfile=$(/usr/bin/mktemp)

  /usr/bin/printf '%s' 'xdg-desktop-portal-termfilechooser saving files tutorial

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!                 === WARNING! ===                 !!!
!!! The contents of *whatever* file you open last in !!!
!!! yazi will be *overwritten*!                    !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Instructions:
1) Move this file wherever you want.
2) Rename the file if needed.
3) Confirm your selection by opening the file, for
   example by pressing <Enter>.

Notes:
1) This file is provided for your convenience. You can
	 only choose this placeholder file otherwise the save operation aborted.
2) If you quit yazi without opening a file, this file
   will be removed and the save operation aborted.
' >"$path"
  set -- --chooser-file="$tmpfile" "$path"
elif [ "$directory" = "1" ]; then
  set -- --cwd-file="$out" "$path"
elif [ "$multiple" = "1" ]; then
  set -- --chooser-file="$out" "$path"
else
  set -- --chooser-file="$out" "$path"
fi

"${termcmd[@]}" -- "$cmd" "$@"

if [ "$save" = "1" ] && [ -s "$tmpfile" ]; then
  selected_file=$(/usr/bin/head -n 1 "$tmpfile")
  if [ -f "$selected_file" ] && /usr/bin/grep -qi "^xdg-desktop-portal-termfilechooser saving files tutorial" "$selected_file"; then
    /usr/bin/echo "$selected_file" >"$out"
    path="$selected_file"
  fi
fi
