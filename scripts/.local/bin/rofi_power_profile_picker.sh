#!/usr/bin/env bash
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u low -t 2500 "Power Profiles" "$1"
  else
    printf '%s\n' "$1"
  fi
}

die() {
  local message="$1"
  notify "$message"
  printf 'Error: %s\n' "$message" >&2
  exit 1
}

ROFI_PROMPT="  power profile"
ROFI_BASE=(
  rofi -dmenu -i -markup-rows -p "$ROFI_PROMPT"
  -show-icons false
  -theme-str ' element { padding: 6px; }
               element-icon { size: 0; }'
)

rofi_escape() {
  local str="$1"
  str="${str//&/&amp;}"
  str="${str//</&lt;}"
  str="${str//>/&gt;}"
  printf '%s' "$str"
}

trim() {
  local value
  value="$(printf '%s\n' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  printf '%s' "$value"
}

profile_icon() {
  case "$1" in
    power-saver|powersave|power-save)
      printf ''
      ;;
    balanced|balanced-performance|balanced-power)
      printf ''
      ;;
    performance|balanced-performance-mode|performance-mode)
      printf '󰓅'
      ;;
    quiet|quiet-mode|cool)
      printf ''
      ;;
    *)
      printf ''
      ;;
  esac
}

if ! have rofi; then
  printf 'Error: rofi is required but not in PATH.\n' >&2
  exit 1
fi

if ! have powerprofilesctl; then
  notify "powerprofilesctl command not found."
  exit 1
fi

active_profile=""
if ! active_profile="$(powerprofilesctl get 2>/dev/null)"; then
  active_profile=""
fi

list_output=""
if ! list_output="$(powerprofilesctl list 2>&1)"; then
  die "Failed to list power profiles. $(printf '%s' "$list_output" | head -n1)"
fi

declare -a profiles=()
declare -a descriptions=()
declare -A seen=()

while IFS= read -r raw_line; do
  [[ -n "${raw_line//[[:space:]]/}" ]] || continue

  line="${raw_line#"${raw_line%%[![:space:]]*}"}"
  [[ -n "$line" ]] || continue

  if [[ "${line:0:1}" == "*" ]]; then
    line="${line:1}"
    line="${line#"${line%%[![:space:]]*}"}"
  fi

  if [[ "$line" != *" - "* && "$line" != *":"* ]]; then
    continue
  fi

  name="$line"
  desc=""

  if [[ "$line" == *" - "* ]]; then
    desc="${line#* - }"
    name="${line%% - *}"
  elif [[ "$line" == *":"* ]]; then
    desc="${line#*:}"
    name="${line%%:*}"
  fi

  name="$(trim "$name")"
  desc="$(trim "$desc")"
  [[ -n "$name" ]] || continue

  lower_name="${name,,}"
  case "$lower_name" in
    driver|drivers|caption|description|available|profiles|profile|active|holds|hold|throttles|throttle|reason|hint|application|applications|version|daemon|powerprofilesctl|default)
      continue
      ;;
  esac

  if [[ ! "$name" =~ ^[[:alnum:]_.:-]+$ ]]; then
    continue
  fi

  if [[ -n "${seen[$name]:-}" ]]; then
    continue
  fi

  seen["$name"]=1
  profiles+=("$name")
  descriptions+=("$desc")
done <<< "$list_output"

if ((${#profiles[@]} == 0)); then
  fallback_profiles=(power-saver balanced performance)
  for fallback in "${fallback_profiles[@]}"; do
    if [[ -z "${seen[$fallback]:-}" ]]; then
      profiles+=("$fallback")
      descriptions+=("")
    fi
  done
fi

if ((${#profiles[@]} == 0)); then
  die "No power profiles found."
fi

declare -a menu_entries=()
for idx in "${!profiles[@]}"; do
  name="${profiles[$idx]}"
  desc="${descriptions[$idx]}"
  icon="$(profile_icon "$name")"
  escaped_name="$(rofi_escape "$name")"
  entry="$icon  "
  if [[ -n "$active_profile" && "$name" == "$active_profile" ]]; then
    entry+="<span weight='bold'>$escaped_name</span> <span size='small'>(current)</span>"
  else
    entry+="$escaped_name"
  fi
  if [[ -n "$desc" ]]; then
    entry+=" <span size='small'>$(rofi_escape "$desc")</span>"
  fi
  menu_entries+=("$entry")
done

choice="$(printf '%s\n' "${menu_entries[@]}" | "${ROFI_BASE[@]}")" || exit 1
[[ -z "${choice:-}" ]] && exit 0

selected_idx=-1
for idx in "${!menu_entries[@]}"; do
  if [[ "${menu_entries[$idx]}" == "$choice" ]]; then
    selected_idx="$idx"
    break
  fi
done

if (( selected_idx < 0 )); then
  exit 0
fi

selected_profile="${profiles[$selected_idx]}"
if [[ -n "$active_profile" && "$selected_profile" == "$active_profile" ]]; then
  exit 0
fi

if set_output="$(powerprofilesctl set "$selected_profile" 2>&1)"; then
  notify "Switched to ${selected_profile}."
  exit 0
fi

printf 'Error: %s\n' "$set_output" >&2

hold_info="$(powerprofilesctl list-holds 2>/dev/null || true)"
if [[ -n "${hold_info//[[:space:]]/}" ]]; then
  notify "Failed to switch. Active holds:\n$hold_info"
else
  notify "Failed to switch to ${selected_profile}."
fi

exit 1
