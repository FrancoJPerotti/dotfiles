#!/usr/bin/env bash
set -euo pipefail

ROFI_PROMPT="  layout"
ROFI_BASE=(
  rofi -dmenu -i -markup-rows -p "$ROFI_PROMPT"
  -show-icons false
  -theme-str ' element { padding: 6px; }
               element-icon { size: 0; }'
)

KANATA_SCRIPT="$HOME/dotfiles/scripts/.local/bin/kanata_up.sh"
STATE_FILE="$HOME/.current_xkb_layout"

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u low -t 2500 "Keyboard Layout" "$1"
  else
    printf '%s\n' "$1"
  fi
}

determine_kanata_name() {
  if [[ -n "${KANATA_BIN:-}" ]]; then
    basename "${KANATA_BIN}"
    return
  fi
  if kanata_path="$(command -v kanata 2>/dev/null)" && [[ -n "$kanata_path" ]]; then
    basename "$kanata_path"
    return
  fi
  for candidate in "$HOME/.cargo/bin/kanata" "$HOME/.local/bin/kanata"; do
    if [[ -x "$candidate" ]]; then
      basename "$candidate"
      return
    fi
  done
  printf '%s' kanata
}

KANATA_NAME="$(determine_kanata_name)"

stop_kanata() {
  pkill -x "$KANATA_NAME" >/dev/null 2>&1 || true
}

write_state() {
  printf '%s' "$1" >"$STATE_FILE"
}

menu_entries=(
  "  custom (kanata)"
  "  us intl"
  "󰌌  us (fallback)"
)

choice="$(printf '%s\n' "${menu_entries[@]}" | "${ROFI_BASE[@]}")" || exit 1
[[ -z "${choice:-}" ]] && exit 0

case "$choice" in
"  custom (kanata)")
  if [[ ! -x "$KANATA_SCRIPT" ]]; then
    notify "Missing helper: $KANATA_SCRIPT"
    exit 1
  fi
  "$KANATA_SCRIPT" --ensure
  notify "Activated custom layout."
  ;;
"  us intl")
  stop_kanata
  if setxkbmap us intl; then
    write_state "us-intl"
    notify "Switched to US International layout."
  else
    notify "Failed to set US International layout."
    exit 1
  fi
  ;;
"󰌌  us (fallback)")
  stop_kanata
  if setxkbmap us; then
    write_state "us"
    notify "Switched to US layout."
  else
    notify "Failed to set US layout."
    exit 1
  fi
  ;;
*)
  exit 0
  ;;
esac
