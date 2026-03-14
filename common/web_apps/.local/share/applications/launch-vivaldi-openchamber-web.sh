#!/usr/bin/env bash

set -euo pipefail

# Rofi/WM sessions may have a very minimal PATH (e.g. missing nvm/cargo).
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
lock_file="${runtime_dir}/openchamber-webapp.lock"
cooldown_file="${runtime_dir}/openchamber-webapp.lastopen"

acquire_lock() {
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$lock_file"
    flock -n 9 || exit 0
    return 0
  fi

  if mkdir "${lock_file}.d" 2>/dev/null; then
    trap 'rmdir "${lock_file}.d" 2>/dev/null || true' EXIT
    return 0
  fi

  exit 0
}

cooldown_guard() {
  local now last
  now="$(date +%s)"
  last="$(cat "$cooldown_file" 2>/dev/null || true)"
  if [[ "$last" =~ ^[0-9]+$ ]] && (( now - last < 2 )); then
    exit 0
  fi
  printf '%s\n' "$now" >"$cooldown_file" 2>/dev/null || true
}

acquire_lock
cooldown_guard

log_file="${XDG_STATE_HOME:-$HOME/.local/state}/openchamber-web.log"
vivaldi_bin="/opt/vivaldi/vivaldi"

resolve_openchamber() {
  local candidate

  if candidate="$(command -v openchamber 2>/dev/null)"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  for candidate in \
    "$HOME/.nvm/versions/node"/*/bin/openchamber \
    "$HOME/.local/bin/openchamber" \
    "$HOME/.cargo/bin/openchamber" \
    "/usr/local/bin/openchamber" \
    "/usr/bin/openchamber"
  do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

extract_port_from_status() {
  local openchamber_bin="$1"

  # Try to extract the first port-like number from `openchamber status`.
  # Expected example (from user): "port 46091"
  "$openchamber_bin" status 2>/dev/null | python3 -c 'import re,sys; data=sys.stdin.read(); m=re.search(r"\bport\b[^0-9]*([0-9]{2,5})\b", data, flags=re.I); sys.stdout.write(m.group(1) if m else "")'
}

extract_port_from_log() {
  local f="$1"

  [ -f "$f" ] || return 0

  python3 - "$f" <<'PY'
import re
import sys

path = sys.argv[1]
try:
    data = open(path, "r", encoding="utf-8", errors="replace").read()
except Exception:
    sys.exit(0)

ports = re.findall(r"\bport\b[^0-9]*([0-9]{2,5})\b", data, flags=re.IGNORECASE)
if ports:
    sys.stdout.write(ports[-1])
PY
}

is_server_ready() {
  python3 - "$1" <<'PY'
import sys
import urllib.request
import urllib.error

url = sys.argv[1]

req = urllib.request.Request(url, headers={"User-Agent": "openchamber-launcher"})
try:
    with urllib.request.urlopen(req, timeout=0.5) as resp:
        # Any successful HTTP response means the server is up.
        sys.exit(0)
except urllib.error.HTTPError as e:
    # If UI auth is enabled, the server may reply with 401/403.
    if e.code in (401, 403):
        sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
PY
}

if [ ! -x "$vivaldi_bin" ]; then
  printf 'Vivaldi is not available at %s.\n' "$vivaldi_bin" >&2
  exit 1
fi

openchamber_bin=""
if ! openchamber_bin="$(resolve_openchamber)"; then
  printf 'openchamber is not installed or not in PATH.\n' >&2
  exit 1
fi

mkdir -p "$(dirname "$log_file")"

port="$(extract_port_from_status "$openchamber_bin" || true)"

if [ -z "${port:-}" ]; then
  # Start (daemon mode by default). Prevent it from launching a browser itself.
  nohup env BROWSER=/bin/true "$openchamber_bin" >"$log_file" 2>&1 &

  for _ in $(seq 1 150); do
    port="$(extract_port_from_status "$openchamber_bin" || true)"
    [ -n "${port:-}" ] || port="$(extract_port_from_log "$log_file" || true)"
    if [ -n "${port:-}" ]; then
      url="http://127.0.0.1:${port}/"
      if is_server_ready "$url"; then
        break
      fi
    fi
    sleep 0.1
  done
else
  url="http://127.0.0.1:${port}/"
fi

if [ -z "${port:-}" ]; then
  printf 'OpenChamber did not report a port. Check %s for details.\n' "$log_file" >&2
  exit 1
fi

url="http://127.0.0.1:${port}/"

if ! is_server_ready "$url"; then
  # Give it a little extra time even if the port is known.
  for _ in $(seq 1 100); do
    if is_server_ready "$url"; then
      break
    fi
    sleep 0.1
  done
fi

if ! is_server_ready "$url"; then
  printf 'OpenChamber web did not start on %s. Check %s for details.\n' "$url" "$log_file" >&2
  exit 1
fi

exec "$vivaldi_bin" --app="$url"
