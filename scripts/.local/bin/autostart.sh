#!/usr/bin/env bash
set -euo pipefail

need() { command -v "$1" >/dev/null || { echo "❌ Missing: $1"; exit 1; }; }
need i3-msg
need jq

# Print a single integer (0+) for the given workspace, even on errors.
count_windows() {
  local ws="${1-}"
  if [ -z "${ws}" ]; then
    echo 0
    return 0
  fi

  local out
  out="$(
    i3-msg -t get_tree 2>/dev/null | jq -r --arg ws "$ws" '
      (recurse(.nodes[]?, .floating_nodes[]?) | select(.type=="workspace" and .name==$ws)) as $w
      | if $w
        then ($w | [recurse(.nodes[]?, .floating_nodes[]?) | select(.window? != null)] | length)
        else 0
        end
    ' 2>/dev/null || echo 0
  )"

  [[ "${out}" =~ ^[0-9]+$ ]] || out=0
  echo "${out}"
}

launch_pwa() {
  # Defensive parsing first so we never reference unset vars under set -u
  if [ "$#" -lt 2 ]; then
    echo "❌ launch_pwa: usage: launch_pwa <tag> <url>" >&2
    return 1
  fi
  local tag app ws before cur
  tag="$1"
  app="$2"
  ws="${tag}"

  echo "→ Starting ${tag}…"

  before="$(count_windows "${ws}")"
  [[ "${before}" =~ ^[0-9]+$ ]] || before=0

  # Create/select the workspace and start the PWA
  i3-msg -q "workspace \"${ws}\"; exec --no-startup-id /opt/vivaldi/vivaldi --app=${app}" &

  # Poll until we see a new window in that workspace
  local i=0
  while [ $i -lt 50 ]; do
    cur="$(count_windows "${ws}")"
    [[ "${cur}" =~ ^[0-9]+$ ]] || cur=0
    if (( cur > before )); then
      echo "   ↳ ${tag} ready."
      return 0
    fi
    i=$((i+1))
    sleep 0.1
  done

  echo "❌ Timed out waiting for ${tag} window!"
  return 1
}

###############################################################################
# PWAs (each gets its own workspace: pwa:<tag>)
###############################################################################
launch_pwa spotify  "https://spotify.com"
launch_pwa whatsapp "https://web.whatsapp.com"
launch_pwa discord  "https://discord.com/app"
launch_pwa ticktick "https://ticktick.com"
launch_pwa chatgpt  "https://chatgpt.com"

# Non-PWA apps
i3-msg -q 'exec --no-startup-id obsidian' &

###############################################################################
# Regular workspaces / utilities
###############################################################################
i3-msg -q 'exec --no-startup-id kitty --class nvim --title nvim nvim' &
i3-msg -q 'exec --no-startup-id kitty --class term' &
i3-msg -q 'exec --no-startup-id kitty --class yazi --title yazi yazi' &

sleep 1
i3-msg -q 'workspace web'
i3-msg -q 'exec --no-startup-id vivaldi'
