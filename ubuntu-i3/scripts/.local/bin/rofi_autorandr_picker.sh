#!/usr/bin/env bash
set -euo pipefail

# Rofi picker for autorandr profiles
# Shows current/detected profiles, allows saving a new setup, and reloads polybar after switching.

have() { command -v "$1" >/dev/null 2>&1; }

if ! have autorandr; then
  echo "autorandr is required but not found in PATH." >&2
  exit 1
fi

run_rofi() {
  local prompt="$1"; shift
  rofi -dmenu -i -markup-rows -p "$prompt" \
    -show-icons false \
    -theme-str ' element { padding: 6px; }
                 element-icon { size: 0; }' \
    "$@"
}

if have notify-send; then
  NOTIFY=(notify-send -u low -t 2500 autorandr)
else
  NOTIFY=(printf '%s\n')
fi

declare -a menu_entries=()
declare -a entry_actions=()
declare -A seen=()
profile_count=0

declare -a circled_digits=("" "①" "②" "③" "④" "⑤" "⑥" "⑦" "⑧" "⑨" "⑩" "⑪" "⑫" "⑬" "⑭" "⑮" "⑯" "⑰" "⑱" "⑲" "⑳")

number_icon() {
  local idx="$1"
  if (( idx > 0 && idx < ${#circled_digits[@]} )); then
    printf '%s' "${circled_digits[idx]}"
  else
    printf '#%d' "$idx"
  fi
}

append_profile_entry() {
  local name="$1" label="$2"
  [[ -n "${seen[$name]:-}" ]] && return
  seen["$name"]=1
  profile_count=$((profile_count + 1))
  local icon
  icon="$(number_icon "$profile_count")"
  menu_entries+=("${icon}  ${label}")
  entry_actions+=("profile:${name}")
}

append_save_entry() {
  local label="$1"
  menu_entries+=("$label")
  entry_actions+=("save")
}

mapfile -t raw_profiles < <(autorandr --list 2>/dev/null || true)

for line in "${raw_profiles[@]}"; do
  [[ -n "${line//[[:space:]]/}" ]] || continue

  # Trim leading whitespace
  line="${line#"${line%%[![:space:]]*}"}"

  # Extract markers (* current, + detected, ! failed)
  prefix=""
  while [[ -n "$line" ]]; do
    case "${line:0:1}" in
      '*'|'+'|'!') prefix+="${line:0:1}"; line="${line:1}";;
      *) break;;
    esac
  done

  line="${line#"${line%%[![:space:]]*}"}"
  [[ -n "$line" ]] || continue

  name="$line"
  statuses=()
  [[ "$prefix" == *"*"* ]] && statuses+=("[current]")
  [[ "$prefix" == *"+"* ]] && statuses+=("[detected]")
  [[ "$prefix" == *"!"* ]] && statuses+=("[failed]")

  label="$name"
  if ((${#statuses[@]} > 0)); then
    label+=" ${statuses[*]}"
  fi

  append_profile_entry "$name" "$label"
done

if ((${#menu_entries[@]} == 0)); then
  cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/autorandr"
  if [[ -d "$cfg_dir" ]]; then
    while IFS= read -r profile; do
      [[ -z "$profile" ]] && continue
      append_profile_entry "$profile" "$profile"
    done < <(find -L "$cfg_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  fi
fi

if ((${#menu_entries[@]} == 0)); then
  "${NOTIFY[@]}" "No autorandr profiles found."
  exit 0
fi

append_save_entry "  Save current setup…"

choice="$(printf '%s\n' "${menu_entries[@]}" | run_rofi "  displays")"
[[ -z "${choice:-}" ]] && exit 0

selected_action=""
for idx in "${!menu_entries[@]}"; do
  if [[ "${menu_entries[$idx]}" == "$choice" ]]; then
    selected_action="${entry_actions[$idx]}"
    break
  fi
done

case "$selected_action" in
  profile:*)
    profile="${selected_action#profile:}"
    [[ -z "$profile" ]] && exit 0

    if autorandr --load "$profile"; then
      "${NOTIFY[@]}" "Loaded profile: $profile"
      if [[ -x "$HOME/.local/bin/launch_polybar.sh" ]]; then
        "$HOME/.local/bin/launch_polybar.sh"
      else
        "$HOME/dotfiles/scripts/.local/bin/launch_polybar.sh" 2>/dev/null || true
      fi
      if [[ -x "$HOME/.local/bin/apply_wallpaper.sh" ]]; then
        "$HOME/.local/bin/apply_wallpaper.sh"
      else
        "$HOME/dotfiles/scripts/.local/bin/apply_wallpaper.sh" 2>/dev/null || true
      fi
    else
      "${NOTIFY[@]}" "Failed to load profile: $profile"
      exit 1
    fi
    ;;
  save)
    name_prompt="$(printf '\n' | run_rofi "  save profile as" -lines 0 -width 40)"
    name_prompt="$(printf '%s' "$name_prompt" | sed 's/^[[:space:]]\+//; s/[[:space:]]\+$//')"
    [[ -z "$name_prompt" ]] && exit 0

    if autorandr --save "$name_prompt"; then
      "${NOTIFY[@]}" "Saved profile: $name_prompt"
    else
      "${NOTIFY[@]}" "Failed to save profile: $name_prompt"
      exit 1
    fi
    ;;
  *)
    exit 0
    ;;
esac
