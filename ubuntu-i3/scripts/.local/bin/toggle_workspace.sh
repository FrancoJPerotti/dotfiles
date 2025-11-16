#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: toggle-workspace.sh [--tabbed] <workspace-name>

Toggles to <workspace-name>, remembering the previous workspace.
If you are already in <workspace-name>, returns to the remembered one.
--tabbed  Force 'layout tabbed' on that workspace when entering.
EOF
}

# ---------- parse args ----------
tabbed=0
ws=""

while (($#)); do
  case "$1" in
  --tabbed)
    tabbed=1
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    break
    ;;
  -*)
    echo "Unknown flag: $1" >&2
    usage
    exit 2
    ;;
  *)
    ws="$1"
    shift
    ;;
  esac
done

[[ -n "${ws:-}" ]] || {
  echo "Missing <workspace-name>"
  usage
  exit 2
}

# ---------- state file ----------
state_dir="${XDG_RUNTIME_DIR:-/tmp}"
slug="$(printf '%s' "$ws" | tr -cs '[:alnum:]_.-' '-')"
state_file="$state_dir/i3-lastws-$slug"

# ---------- get current ----------
current="$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused).name')"

if [[ "$current" == "$ws" ]]; then
  # Return to where you came from (or fall back to back_and_forth)
  if [[ -s "$state_file" ]]; then
    prev="$(cat "$state_file")"
    i3-msg "workspace $prev" >/dev/null
  else
    i3-msg 'workspace back_and_forth' >/dev/null
  fi
else
  # Remember current, then jump; optionally set tabbed layout
  printf '%s' "$current" >"$state_file"
  cmd="workspace $ws"
  if [[ "$tabbed" -eq 1 ]]; then
    cmd="$cmd; layout tabbed"
  fi
  i3-msg "$cmd" >/devnull 2>&1 || i3-msg "$cmd" >/dev/null
fi
