#!/usr/bin/env bash
# stow_dotfiles.sh — safely stow your dotfiles, optionally removing
# pre‑existing conflicting files first (with preview support).
#
# Usage:
#   ./stow_dotfiles.sh          # normal run – delete conflicts then stow
#   ./stow_dotfiles.sh -n       # dry‑run – just show what would be done
#
# Environment:
#   DOTFILES_DIR  Override the dotfiles directory. Defaults to the directory
#                 this script lives in.
#
# Exit codes: 0 = success, 1 = bad args.

set -euo pipefail

# ── Resolve repository root ────────────────────────────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$SCRIPT_DIR}"

# Packages whose directories should be skipped entirely (metadata, helper files)
EXCLUDED=(custom vivaldi README.md pkglist.txt aurlist.txt .git .github .stow-local-ignore)

# ── Flags ────────────────────────────────────────────────────────────────────
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $0 [--dry-run|-n] [--help|-h]

Options:
  -n, --dry-run  Preview only – report what *would* be removed/linked.
  -h, --help     Show this help.

Environment:
  DOTFILES_DIR   Path to your dotfiles repo (default: script's directory).
EOF
}

# ── CLI parsing ─────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
  -n | --dry-run)
    DRY_RUN=true
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "❌ Unknown option: $1"
    usage
    exit 1
    ;;
  esac
done

$DRY_RUN && echo "🧪 Dry‑run mode – no changes will be made."

echo "📦 Using dotfiles directory: $DOTFILES_DIR"

# ── Helpers ────────────────────────────────────────────────────────────────
info() { printf "ℹ️  %s\n" "$*"; }
warn() { printf "⚠️  %s\n" "$*"; }

# cleanup_conflicts <package-path>
# ---------------------------------------------------------------------------
#   1. Runs `stow -nv` to detect conflicts.
#   2. Prints (or deletes) every conflicting path.
#   3. For dry‑runs, also echoes Stow's simulated actions so you see the links
#      that would be created.
# ---------------------------------------------------------------------------
cleanup_conflicts() {
  local pkg_path="$1"
  local -a conflicts=()

  # Run stow simulation; capture output (exit 2 is expected when conflicts).
  local sim_out
  if ! sim_out=$( (cd "$pkg_path" && stow -nv -t "$HOME" .) 2>&1); then
    :
  fi

  # ── Extract conflicting target paths ────────────────────────────────────
  while IFS= read -r line; do
    # 1. "existing target is not owned by stow: <path>"
    if [[ $line =~ existing[[:space:]]target.*:[[:space:]](.+)$ ]]; then
      conflicts+=("$HOME/${BASH_REMATCH[1]}")
      continue
    fi
    # 2. "existing target is a directory: <path>"
    if [[ $line =~ existing[[:space:]]target[[:space:]]is[[:space:]]a[[:space:]]directory:[[:space:]](.+)$ ]]; then
      conflicts+=("$HOME/${BASH_REMATCH[1]}")
      continue
    fi
    # 3. "CONFLICT: <path>"
    if [[ $line =~ CONFLICT:[[:space:]](.+)$ ]]; then
      conflicts+=("$HOME/${BASH_REMATCH[1]}")
      continue
    fi
    # 4. "cannot stow X over existing target <path> since …"
    if [[ $line =~ cannot[[:space:]]stow[[:space:]].*over[[:space:]]existing[[:space:]]target[[:space:]]([^[:space:]]+) ]]; then
      conflicts+=("$HOME/${BASH_REMATCH[1]}")
      continue
    fi
  done <<<"$sim_out"

  # ── Report / remove conflicts ───────────────────────────────────────────
  for f in "${conflicts[@]}"; do
    if $DRY_RUN; then
      echo "🗑️  Would remove: $f"
    else
      if [[ -e $f || -L $f ]]; then
        echo "🗑️  Removing: $f"
        rm -rf -- "$f"
      fi
    fi
  done

  if $DRY_RUN; then
    echo "$sim_out"
  fi
}

# ── Main loop ───────────────────────────────────────────────────────────────
for pkg_path in "$DOTFILES_DIR"/*; do
  pkg_name="$(basename "$pkg_path")"

  # Skip excluded directories
  if printf '%s\n' "${EXCLUDED[@]}" | grep -qx "$pkg_name"; then
    info "⏭️  Skipping $pkg_name"
    continue
  fi

  [[ -d $pkg_path ]] || continue

  echo -e "\n🔗 Processing package: $pkg_name"

  # 1) Detect conflicts and (optionally) remove them *before* real stow.
  cleanup_conflicts "$pkg_path"

  # 2) If not a dry‑run, perform the actual stow. Any non‑zero exit is logged
  #    as a warning but will not abort the loop (thanks to the `!` guard).
  if ! $DRY_RUN; then
    if ! (cd "$pkg_path" && stow -t "$HOME" .); then
      warn "Stow reported issues for $pkg_name — continuing with next package."
    fi
  fi

done

echo -e "\n✅ Done."
