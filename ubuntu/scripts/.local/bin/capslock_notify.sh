#!/usr/bin/env bash
set -euo pipefail
LC_ALL=C

interval="${CAPSLOCK_NOTIFY_INTERVAL:-0.05}"
notify_title="${CAPSLOCK_NOTIFY_TITLE:-Caps Lock}"
notify_body="${CAPSLOCK_NOTIFY_MESSAGE:-Caps Lock is ON}"
notify_bg="${CAPSLOCK_NOTIFY_BG:-#ff3860}"
notify_fg="${CAPSLOCK_NOTIFY_FG:-#1a1a1a}"
debug="${CAPSLOCK_NOTIFY_DEBUG:-0}"
notify_when_off="${CAPSLOCK_NOTIFY_NOTIFY_OFF:-0}"
stack_tag="${CAPSLOCK_NOTIFY_STACK_TAG:-capslock-state}"
notification_id=""
use_dunstify=0

log_debug() {
  case "${debug}" in
    1|true|TRUE|yes|YES)
      printf 'capslock_notify: %s\n' "$*" >&2
      ;;
  esac
}

if [[ -z "${DISPLAY:-}" ]]; then
  echo "capslock_notify: DISPLAY is not set" >&2
  exit 1
fi

if ! command -v xset >/dev/null 2>&1; then
  echo "capslock_notify: xset not found" >&2
  exit 1
fi

if command -v dunstify >/dev/null 2>&1; then
  use_dunstify=1
elif command -v notify-send >/dev/null 2>&1; then
  use_dunstify=0
else
  echo "capslock_notify: neither dunstify nor notify-send found" >&2
  exit 1
fi

notify_caps() {
  local state="$1"
  local title="${notify_title}"
  local body="${notify_body}"
  local show_off=0

  if [[ "${state}" == "off" ]]; then
    if [[ "${notify_when_off}" =~ ^(1|true|TRUE|yes|YES)$ ]]; then
      show_off=1
      title="${CAPSLOCK_NOTIFY_OFF_TITLE:-Caps Lock}"
      body="${CAPSLOCK_NOTIFY_OFF_MESSAGE:-Caps Lock is OFF}"
    fi
  fi

  if (( use_dunstify )); then
    if [[ "${state}" == "on" ]]; then
      log_debug "Sending notification via dunstify (replace ${notification_id:-0})"
      notification_id="$(
        dunstify \
          --printid \
          --appname "Keyboard" \
          --urgency critical \
          --replace "${notification_id:-0}" \
          --timeout 0 \
          --hints "string:bgcolor:${notify_bg}" \
          --hints "string:fgcolor:${notify_fg}" \
          --hints "string:frcolor:${notify_fg}" \
          "${title}" "${body}" 2>/dev/null || printf '%s' "${notification_id}"
      )"
      log_debug "Notification id is ${notification_id}"
    else
      log_debug "Closing notification id ${notification_id}"
      if [[ -n "${notification_id}" ]]; then
        dunstify --close "${notification_id}" >/dev/null 2>&1 || true
        notification_id=""
      fi
      if (( show_off )); then
        # Optionally show short "off" message
        notification_id="$(
          dunstify \
            --printid \
            --appname "Keyboard" \
            --urgency low \
            --timeout 500 \
            --replace 0 \
            --hints "string:x-dunst-stack-tag:${stack_tag}" \
            "${title}" "${body}" 2>/dev/null || printf ''
        )"
      fi
    fi
  else
    log_debug "Sending notification via notify-send for state ${state}"
    if [[ "${state}" == "on" ]]; then
      notify-send \
        -u critical \
        -a "Keyboard" \
        -t 0 \
        -h "string:x-dunst-stack-tag:${stack_tag}" \
        -h "string:bgcolor:${notify_bg}" \
        -h "string:fgcolor:${notify_fg}" \
        -h "string:frcolor:${notify_fg}" \
        "${title}" "${body}"
    else
      if (( show_off )); then
        notify-send \
          -u low \
          -a "Keyboard" \
          -t 500 \
          -h "string:x-dunst-stack-tag:${stack_tag}" \
          "${title}" "${body}"
      else
        # overwrite with an empty, short-lived notification to clear the stack
        notify-send \
          -u low \
          -a "Keyboard" \
          -t 100 \
          -h "string:x-dunst-stack-tag:${stack_tag}" \
          "" ""
      fi
    fi
  fi
}

read_caps_state() {
  local status
  status="$(xset q 2>/dev/null | awk '/Caps Lock:/ {print $4; exit}')"
  status="${status,,}"
  case "${status}" in
    on|off)
      printf '%s' "${status}"
      ;;
    *)
      printf 'off'
      ;;
  esac
}

current_state="$(read_caps_state)"
log_debug "Initial state ${current_state}"
if [[ "${current_state}" == "on" ]]; then
  notify_caps "on"
fi

while true; do
  sleep "${interval}"
  new_state="$(read_caps_state)"
  if [[ "${new_state}" != "${current_state}" ]]; then
    current_state="${new_state}"
    log_debug "State changed to ${current_state}"
    notify_caps "${current_state}"
  fi
done
