#!/usr/bin/env bash
# rofi_zellij_picker --- manage Zellij workflows and sessions from Rofi.

set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

BACK_SENTINEL="__back"
BACK_LABEL='↩  Back'

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

if ! have rofi; then
  die "rofi is required but not found in PATH."
fi

WORKFLOW_CLI="${WORKFLOW_CLI:-zellij-workflow}"
WORKFLOW_DIR="${ZELLIJ_WORKFLOW_DIR:-$HOME/.config/zellij/workflows}"

if ! have "$WORKFLOW_CLI"; then
  die "'$WORKFLOW_CLI' is required but not found in PATH."
fi

spawn_editor() {
  local file="$1"
  local choice
  local -a pieces
  local IFS=$' \t\n'
  if [[ -n "${GUI_EDITOR:-}" ]]; then
    choice="$GUI_EDITOR"
  elif [[ -n "${TERMINAL_EDITOR:-}" ]]; then
    choice="$TERMINAL_EDITOR"
  else
    choice="${EDITOR:-nvim}"
  fi

  read -r -a pieces <<< "$choice"
  local -a editor_cmd=("${pieces[@]}")

  if [[ ${#editor_cmd[@]} -eq 0 ]]; then
    editor_cmd=("nvim")
  fi

  if [[ "${editor_cmd[0]}" == "nvim" ]]; then
    editor_cmd=(kitty nvim)
  fi

  command nohup "${editor_cmd[@]}" "$file" >/dev/null 2>&1 &
}

workflow_cli() {
  "$WORKFLOW_CLI" --workflow-dir "$WORKFLOW_DIR" "$@"
}

run_rofi_index() {
  local prompt="$1"
  shift
  rofi -dmenu -i -markup-rows -p "$prompt" \
    -format i \
    -theme-str ' element { padding: 6px; }
                 element-icon { size: 0; }' \
    "$@"
}

build_status_badge() {
  local status="$1"
  case "$status" in
  active)
    printf '<span foreground="#8ec07c">active</span>'
    ;;
  exited|detached)
    printf '<span foreground="#fe8019">detached</span>'
    ;;
  missing|*)
    printf '<span foreground="#fb4934">not running</span>'
    ;;
  esac
}

pick_workflow() {
  local -a rows=("$BACK_LABEL")
  local -a keys=("$BACK_SENTINEL")

  IFS=$'\n' read -r -d '' -a workflow_lines < <(workflow_cli list --format tsv && printf '\0')
  declare -A status_by_session=()

  IFS=$'\n' read -r -d '' -a session_lines < <(workflow_cli sessions --format tsv && printf '\0')
  for line in "${session_lines[@]}"; do
    [[ -z "$line" ]] && continue
    IFS=$'\t' read -r session status wf_key wf_name <<<"$line"
    [[ -n "$session" ]] || continue
    status_by_session["$session"]="$status"
  done

  for line in "${workflow_lines[@]}"; do
    [[ -z "$line" ]] && continue
    IFS=$'\t' read -r key name session desc <<<"$line"
    [[ -n "$key" ]] || continue
    local status="${status_by_session[$session]:-missing}"
    local badge
    badge="$(build_status_badge "$status")"
    local title="$name"
    if [[ -n "$desc" ]]; then
      title="$title <span size=\"small\" foreground=\"#888888\">— $desc</span>"
    fi
    rows+=("  $title  <span size=\"small\">[$badge]</span>")
    keys+=("$key")
  done

  [[ ${#rows[@]} -gt 0 ]] || return 1

  local choice
  choice="$(printf '%s\n' "${rows[@]}" | run_rofi_index "Workflow")" || return 1
  [[ -n "$choice" && "$choice" != "-1" ]] || return 1
  local selected=""
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    selected="${keys[choice]}"
  else
    for idx in "${!rows[@]}"; do
      if [[ "${rows[idx]}" == "$choice" ]]; then
        selected="${keys[idx]}"
        break
      fi
    done
  fi
  [[ -n "$selected" ]] || return 1
  printf '%s\n' "$selected"
}

workflow_actions_menu() {
  local workflow_key="$1"
  local -a options=(
    "$BACK_LABEL"
    "  Start / Attach…"
    "  Start Fresh…"
    "  Open Manifest"
  )
  local selection
  selection="$(printf '%s\n' "${options[@]}" | run_rofi_index "$workflow_key")" || return 1
  [[ -n "$selection" && "$selection" != "-1" ]] || return 1
  if [[ "$selection" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$selection"
  else
    for idx in "${!options[@]}"; do
      if [[ "${options[idx]}" == "$selection" ]]; then
        printf '%s\n' "$idx"
        return 0
      fi
    done
    return 1
  fi
}

pick_session() {
  local -a rows=("$BACK_LABEL")
  local -a names=("$BACK_SENTINEL")

  IFS=$'\n' read -r -d '' -a session_lines < <(workflow_cli sessions --format tsv && printf '\0')
  [[ ${#session_lines[@]} -gt 0 ]] || return 1

  for line in "${session_lines[@]}"; do
    [[ -z "$line" ]] && continue
    # wf_key is used in the read but not referenced later
    # shellcheck disable=SC2034
    IFS=$'\t' read -r session status wf_key wf_name <<<"$line"
    [[ -n "$session" ]] || continue
    local label="${wf_name:-$session}"
    local badge
    badge="$(build_status_badge "$status")"
    rows+=("  $label <span size=\"small\" foreground=\"#888888\">($session)</span> <span size=\"small\">[$badge]</span>")
    names+=("$session")
  done

  local choice
  choice="$(printf '%s\n' "${rows[@]}" | run_rofi_index "Session")" || return 1
  [[ -n "$choice" && "$choice" != "-1" ]] || return 1
  local selected=""
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    selected="${names[choice]}"
  else
    for idx in "${!rows[@]}"; do
      if [[ "${rows[idx]}" == "$choice" ]]; then
        selected="${names[idx]}"
        break
      fi
    done
  fi
  [[ -n "$selected" ]] || return 1
  printf '%s\n' "$selected"
}

session_actions_menu() {
  local session="$1"
  local -a options=(
    "$BACK_LABEL"
    "  Attach…"
    "  Kill"
  )
  local selection
  selection="$(printf '%s\n' "${options[@]}" | run_rofi_index "$session")" || return 1
  [[ -n "$selection" && "$selection" != "-1" ]] || return 1
  if [[ "$selection" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$selection"
  else
    for idx in "${!options[@]}"; do
      if [[ "${options[idx]}" == "$selection" ]]; then
        printf '%s\n' "$idx"
        return 0
      fi
    done
    return 1
  fi
}

notify_msg() {
  if have notify-send; then
    notify-send -u low -t 2000 "Zellij" "$1"
  else
    printf 'Zellij: %s\n' "$1" >&2
  fi
}

handle_workflows() {
  local key
  key="$(pick_workflow)" || return 1

  if [[ "$key" == "$BACK_SENTINEL" ]]; then
    return 0
  fi

  local action
  action="$(workflow_actions_menu "$key")" || return 1

  if [[ "$action" == "0" ]]; then
    return 0
  fi

  case "$action" in
  1)
    if workflow_cli start "$key" >/dev/null 2>&1; then
      notify_msg "Launching workflow '$key'"
    else
      notify_msg "Failed to launch '$key'"
    fi
    exit 0
    ;;
  2)
    if workflow_cli start --recreate "$key" >/dev/null 2>&1; then
      notify_msg "Recreating workflow '$key'"
    else
      notify_msg "Failed to recreate '$key'"
    fi
    exit 0
    ;;
  3)
    local manifest="$WORKFLOW_DIR/$key.toml"
    if [[ -f "$manifest" ]]; then
      spawn_editor "$manifest"
    else
      notify_msg "Manifest not found for '$key'"
    fi
    exit 0
    ;;
  esac
}

handle_sessions() {
  local session
  session="$(pick_session)" || return 1

  if [[ "$session" == "$BACK_SENTINEL" ]]; then
    return 0
  fi

  local action
  action="$(session_actions_menu "$session")" || return 1

  if [[ "$action" == "0" ]]; then
    return 0
  fi

  case "$action" in
  1)
    if workflow_cli attach "$session" >/dev/null 2>&1; then
      notify_msg "Attaching to '$session'"
    else
      notify_msg "Failed to attach to '$session'"
    fi
    exit 0
    ;;
  2)
    if workflow_cli kill "$session" >/dev/null 2>&1; then
      notify_msg "Killing session '$session'"
    else
      notify_msg "Failed to kill session '$session'"
    fi
    exit 0
    ;;
  esac
}

main_menu() {
  local -a options=(
    "  Workflows"
    "  Sessions"
  )
  local choice
  choice="$(printf '%s\n' "${options[@]}" | run_rofi_index "Zellij")" || return 1
  [[ -n "$choice" && "$choice" != "-1" ]] || return 1
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$choice"
  else
    for idx in "${!options[@]}"; do
      if [[ "${options[idx]}" == "$choice" ]]; then
        printf '%s\n' "$idx"
        return 0
      fi
    done
    return 1
  fi
}

while true; do
  choice="$(main_menu)" || exit 0
  case "$choice" in
  0) handle_workflows ;;
  1) handle_sessions ;;
  *) exit 0 ;;
  esac
done
