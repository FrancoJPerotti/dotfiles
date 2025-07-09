#!/usr/bin/env bash
# stow_dotfiles.sh — safely stow your dotfiles, optionally removing
# pre-existing conflicting files first (with preview support).
#
# Usage:
#   ./stow_dotfiles.sh          # normal run – delete conflicts then stow
#   ./stow_dotfiles.sh -n       # dry‑run – just show what would be done
#
# Environment:
#   DOTFILES_DIR  Override the dotfiles directory. Defaults to the directory
#                 this script lives in.
#
# Exit codes: 0 = success, 1 = bad args or unrecoverable failure.

set -euo pipefail

# ── Resolve repository root ────────────────────────────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$SCRIPT_DIR}"

# Packages whose directories should be skipped entirely (typically metadata)
EXCLUDED=(custom README.md pkglist.txt aurlist.txt .git .github .stow-local-ignore)

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

# ── CLI parsing ───────────────────────────────────────────────────────────────
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

# ── Helpers ───────────────────────────────────────────────────────────────────
info() { printf "ℹ️  %s\n" "$*"; }

# cleanup_conflicts <package‑path>
cleanup_conflicts() {
    local pkg_path="$1"
    local -a conflicts=()

    # Capture stow's simulated actions (exit status 2 is fine for conflicts).
    local output
    if ! output=$( (cd "$pkg_path" && stow -nv -t "$HOME" .) 2>&1); then
        :
    fi

    # Parse conflict lines for nicer "Would remove" hints.
    while IFS= read -r line; do
        if [[ $line =~ existing\ target.*:\ (.*)$ ]]; then
            conflicts+=("$HOME/${BASH_REMATCH[1]}")
        elif [[ $line =~ CONFLICT:\ (.*)$ ]]; then
            conflicts+=("$HOME/${BASH_REMATCH[1]}")
        fi
    done <<<"$output"

    # Show or delete conflicts.
    for f in "${conflicts[@]}"; do
        if $DRY_RUN; then
            echo "🗑️  Would remove: $f"
        else
            [[ -e $f || -L $f ]] && {
                echo "🗑️  Removing: $f"
                rm -rf -- "$f"
            }
        fi
    done

    # In dry‑run mode, also show stow's own planned actions once.
    $DRY_RUN && echo "$output"
}

# ── Main loop ────────────────────────────────────────────────────────────────
for pkg_path in "$DOTFILES_DIR"/*; do
    pkg_name="$(basename "$pkg_path")"

    # Skip excluded directories
    if printf '%s\n' "${EXCLUDED[@]}" | grep -qx "$pkg_name"; then
        info "⏭️  Skipping $pkg_name"
        continue
    fi

    [[ -d $pkg_path ]] || continue

    echo -e "\n🔗 Processing package: $pkg_name"

    if $DRY_RUN; then
        # One call is enough: parse + display in cleanup_conflicts.
        cleanup_conflicts "$pkg_path"
    else
        # 1) Delete conflicts, 2) stow for real.
        cleanup_conflicts "$pkg_path"
        (cd "$pkg_path" && stow -t "$HOME" .)
    fi

done

echo -e "\n✅ Done."
