#!/usr/bin/env bash

set -euo pipefail

port=4096
url="http://127.0.0.1:${port}"
log_file="${XDG_STATE_HOME:-$HOME/.local/state}/opencode-web.log"
vivaldi_bin="/opt/vivaldi/vivaldi"
opencode_bin=""

resolve_opencode() {
  local candidate

  export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

  if candidate="$(command -v opencode 2>/dev/null)"; then
    printf '%s\n' "$candidate"
    return 0
  fi

  for candidate in \
    "$HOME/.nvm/versions/node"/*/bin/opencode \
    "$HOME/.local/bin/opencode" \
    "/usr/local/bin/opencode" \
    "/usr/bin/opencode"
  do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

is_server_ready() {
  python3 - "$url" <<'PY'
import sys
import urllib.request

url = sys.argv[1]

try:
    with urllib.request.urlopen(url, timeout=0.5) as response:
        body = response.read(4096).decode("utf-8", "replace")
except Exception:
    sys.exit(1)

ok = response.status == 200 and "<title>OpenCode</title>" in body
sys.exit(0 if ok else 1)
PY
}

if ! opencode_bin="$(resolve_opencode)"; then
  printf 'opencode is not installed or not in PATH.\n' >&2
  exit 1
fi

if [ ! -x "$vivaldi_bin" ]; then
  printf 'Vivaldi is not available at %s.\n' "$vivaldi_bin" >&2
  exit 1
fi

mkdir -p "$(dirname "$log_file")"

if ! is_server_ready; then
  nohup env BROWSER=/bin/true "$opencode_bin" web --hostname 127.0.0.1 --port "$port" >"$log_file" 2>&1 &

  for _ in $(seq 1 150); do
    if is_server_ready; then
      break
    fi
    sleep 0.1
  done
fi

if ! is_server_ready; then
  printf 'OpenCode web did not start on %s. Check %s for details.\n' "$url" "$log_file" >&2
  exit 1
fi

exec "$vivaldi_bin" --app="$url"
