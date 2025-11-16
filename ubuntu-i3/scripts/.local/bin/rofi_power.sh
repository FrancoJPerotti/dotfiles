#!/usr/bin/env bash
set -euo pipefail

CURRENT_LOCK_WALLPAPER="$HOME/.local/share/wallpapers/current_lock_wallpaper"

# -------- settings --------
LOCK_CMD="i3lock -i "$CURRENT_LOCK_WALLPAPER" -n" # solid black background

ROFI_BASE=(rofi -dmenu -i -markup-rows -p "  power"
  -show-icons false
  -theme-str ' element { padding: 6px; }
               element-icon { size: 0; }'
)

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u low "Power menu" "$1" || true
}

# -------- menu --------
OPTIONS=$(
  cat <<'EOF'
  lock
  suspend
  hibernate
  hybrid-sleep
  reboot
  power off
  logout
  screen off
EOF
)

choice=$(printf "%s" "$OPTIONS" | "${ROFI_BASE[@]}") || exit 1

case "$choice" in
"  lock")
  eval "$LOCK_CMD"
  ;;

"  suspend")
  notify "suspending…"
  eval "$LOCK_CMD" &
  sleep 0.5
  systemctl suspend
  ;;

"  hibernate")
  notify "hibernating…"
  eval "$LOCK_CMD" &
  sleep 0.5
  systemctl hibernate
  ;;

"  hybrid-sleep")
  notify "hybrid sleep…"
  eval "$LOCK_CMD" &
  sleep 0.5
  systemctl hybrid-sleep
  ;;

"  reboot")
  notify "rebooting…"
  systemctl reboot
  ;;

"  power off")
  notify "powering off…"
  systemctl poweroff
  ;;

"  logout")
  notify "logging out…"
  i3-msg exit >/dev/null
  ;;

"  screen off")
  notify "turning display off…"
  xset dpms force off
  ;;

*)
  exit 0
  ;;
esac
