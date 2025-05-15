#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
DOTFILES_DIR="$HOME/dotfiles"
EXCLUDED=("custom" "README.md" "pkglist.txt" "aurlist.txt" ".git" ".github" ".stow-local-ignore")

# --- Flags ---
DRY_RUN=false

# --- Parse arguments ---
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run)
      DRY_RUN=true
      ;;
    *)
      echo "❌ Unknown option: $arg"
      echo "Usage: $0 [--dry-run|-n]"
      exit 1
      ;;
  esac
done

echo "📦 Processing dotfiles from: $DOTFILES_DIR"
$DRY_RUN && echo "🧪 Dry run mode ON — no changes will be made."

# --- Process each subdirectory as a stow package ---
for pkg_path in "$DOTFILES_DIR"/*; do
  pkg_name="$(basename "$pkg_path")"

  # Skip excluded entries
  if printf '%s\n' "${EXCLUDED[@]}" | grep -qx "$pkg_name"; then
    echo "⏭️  Skipping $pkg_name"
    continue
  fi

  [[ -d "$pkg_path" ]] || continue

  echo "🔗 Stowing package: $pkg_name"

  if $DRY_RUN; then
    (cd "$pkg_path" && stow -nv -t ~ .)
  else
    (cd "$pkg_path" && stow -t ~ .)
  fi
done

echo "✅ Done."
