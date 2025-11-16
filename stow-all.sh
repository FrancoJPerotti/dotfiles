#!/usr/bin/env bash
set -euo pipefail

# Unified stow driver for this repo.
# - Stows packages from common/ + a profile directory (e.g., arch/, ubuntu/, work/).
# - Uses per-domain .stow-exclude files to decide which top-level directories
#   should NOT be stowed.
#
# Usage:
#   ./stow-all.sh arch   [-n|--dry-run]
#   ./stow-all.sh ubuntu [-n|--dry-run]
#   ./stow-all.sh work   [-n|--dry-run]
#   ./stow-all.sh <profile> [-n|--dry-run]
#   ./stow-all.sh [-n|--dry-run]  # auto-detect based on distro

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

TARGET_PROFILE=""
DRY_RUN=false

usage() {
  cat <<EOF
Usage:
  $0 [profile] [options]

Examples:
  $0 arch -n
  $0 ubuntu
  $0 work
  $0        # auto-detect profile based on distro

Options:
  -n, --dry-run  Preview only – do not remove or create anything.
  -h, --help     Show this help message.

Behaviour:
  - Runs over two domains: common/ and <profile>/.
  - Profiles can represent different distros, window managers, work configs, etc.
  - For each domain, every top-level directory is treated as a Stow package,
    except those listed in that domain's .stow-exclude file or built-in
    ignores (.git, .github, .stow-local-ignore, .stow-exclude).
EOF
}

# If the first arg is non-empty and not an option, treat it as the profile name.
if [[ $# -gt 0 && $1 != -* ]]; then
  TARGET_PROFILE="$1"
  shift
fi

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# Auto-detect profile based on distro if not explicitly provided
if [[ -z "${TARGET_PROFILE}" && -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    arch|endeavouros|manjaro) TARGET_PROFILE="arch" ;;
    ubuntu|pop|linuxmint|neon|zorin) TARGET_PROFILE="ubuntu" ;;
  esac
fi

if [[ -z "${TARGET_PROFILE}" ]]; then
  echo "❌ Unable to determine target profile. Please specify one explicitly." >&2
  echo "   Available profiles: $(cd "$SCRIPT_DIR" && ls -d */ 2>/dev/null | grep -v common | tr -d '/' | tr '\n' ' ')" >&2
  usage
  exit 1
fi

info() { printf "ℹ️  %s\n" "$*"; }
warn() { printf "⚠️  %s\n" "$*"; }
error() { printf "❌ %s\n" "$*" >&2; }

check_prerequisites() {
  local has_error=false

  # Check if stow is installed
  if ! command -v stow &>/dev/null; then
    error "GNU Stow is not installed."
    echo "   Install with: sudo pacman -S stow  (Arch)" >&2
    echo "            or: sudo apt install stow  (Ubuntu)" >&2
    has_error=true
  fi

  # Check if target profile directory exists
  if [[ ! -d "${SCRIPT_DIR}/${TARGET_PROFILE}" ]]; then
    error "Profile directory not found: ${SCRIPT_DIR}/${TARGET_PROFILE}"
    echo "   Available profiles: $(cd "$SCRIPT_DIR" && ls -d */ 2>/dev/null | grep -v common | tr -d '/' | tr '\n' ' ')" >&2
    has_error=true
  fi

  # Check if common directory exists
  if [[ ! -d "${SCRIPT_DIR}/common" ]]; then
    warn "Common directory not found: ${SCRIPT_DIR}/common"
  fi

  if $has_error; then
    exit 1
  fi
}

check_prerequisites

declare -a EXCLUDED=()

load_excludes() {
  local domain_dir="$1"
  EXCLUDED=()

  local cfg="${domain_dir}/.stow-exclude"
  if [[ -r "$cfg" ]]; then
    # shellcheck disable=SC2207
    EXCLUDED=($(grep -vE '^\s*#' "$cfg" | sed '/^\s*$/d'))
  fi
}

is_excluded() {
  local name="$1"

  case "$name" in
    .git|.github|.stow-local-ignore|.stow-exclude)
      return 0
      ;;
  esac

  for e in "${EXCLUDED[@]}"; do
    [[ "$name" == "$e" ]] && return 0
  done

  return 1
}

# cleanup_conflicts <domain-dir> <package-name>
# ---------------------------------------------------------------------------
#   1. Runs `stow -nv` to detect conflicts.
#   2. Prints (or deletes) every conflicting path.
#   3. For dry-runs, also echoes Stow's simulated actions.
# ---------------------------------------------------------------------------
cleanup_conflicts() {
  local domain_dir="$1"
  local pkg_name="$2"
  local -a conflicts=()

  # Run stow simulation; capture output (exit 2 is expected when conflicts).
  local sim_out
  if ! sim_out=$( stow -nv -d "$domain_dir" -t "$HOME" "$pkg_name" 2>&1 ); then
    :
  fi

  # Extract conflicting target paths
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

  # Report / remove conflicts
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

stow_domain() {
  local domain="$1"
  local domain_dir="${SCRIPT_DIR}/${domain}"

  if [[ ! -d "$domain_dir" ]]; then
    warn "Domain directory not found, skipping: $domain_dir"
    return
  fi

  echo
  echo "📦 Using dotfiles domain: $domain_dir"
  $DRY_RUN && echo "🧪 Dry-run mode – no changes will be made."

  load_excludes "$domain_dir"

  for pkg_path in "$domain_dir"/*; do
    local pkg_name
    pkg_name="$(basename "$pkg_path")"

    [[ -d $pkg_path ]] || continue

    if is_excluded "$pkg_name"; then
      info "⏭️  Skipping $domain/$pkg_name"
      continue
    fi

    echo -e "\n🔗 Processing package: $domain/$pkg_name"

    # 1) Detect conflicts and (optionally) remove them before real stow.
    cleanup_conflicts "$domain_dir" "$pkg_name"

    # 2) Perform the actual stow.
    if ! $DRY_RUN; then
      if ! stow -d "$domain_dir" -t "$HOME" "$pkg_name"; then
        warn "Stow reported issues for $domain/$pkg_name — continuing with next package."
      fi
    fi
  done
}

echo "▶ Target profile: ${TARGET_PROFILE}"

stow_domain "common"
stow_domain "${TARGET_PROFILE}"

echo
echo "✅ Done."
