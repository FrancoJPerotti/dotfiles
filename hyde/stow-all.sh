#!/usr/bin/env bash
set -euo pipefail

# Thin compatibility wrapper.
# Prefer calling ../../stow-all.sh directly:
#   ./stow-all.sh arch [-n|--dry-run]

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
exec "${SCRIPT_DIR}/../stow-all.sh" arch "$@"
