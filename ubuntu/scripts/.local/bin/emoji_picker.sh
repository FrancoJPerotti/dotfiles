#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------
# Rofi Emoji Picker (single-column layout)
# - Data source: Emojibase (English)
# - First run auto-downloads & caches JSON
# - --update refreshes the cache
# - Enter: copy to clipboard
# - Wayland/X11 compatible; chooses the right backend
# ----------------------------------------

# Config / cache paths
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-emoji"
JSON="$CACHE_DIR/emojibase-en.json"
TSV="$CACHE_DIR/emojis.tsv"
EMOJIBASE_URL="https://raw.githubusercontent.com/milesj/emojibase/master/packages/data/en/data.raw.json"

have() { command -v "$1" >/dev/null 2>&1; }
die() {
    printf "rofi-emoji: %s\n" "$*" >&2
    exit 1
}

# Hard deps
have rofi || die "rofi is required"
have jq || die "jq is required"
have curl || die "curl is required"

# ---------------- Backend selection ----------------
# Force backend with ROFI_EMOJI_BACKEND=wayland|x11 (optional)
backend="${ROFI_EMOJI_BACKEND:-auto}"
if [[ "$backend" == "auto" ]]; then
    if [[ -n "${WAYLAND_DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
        backend="wayland"
    elif [[ -n "${DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == "x11" ]]; then
        backend="x11"
    else
        # Fallback to x11; safer on non-Wayland WMs like i3
        backend="x11"
    fi
fi

copy_cmd=""
type_cmd=""
if [[ "$backend" == "wayland" ]]; then
    [[ -z "${WAYLAND_DISPLAY:-}" ]] && die "Wayland backend selected but WAYLAND_DISPLAY is unset"
    if have wl-copy; then copy_cmd="wl-copy"; fi
    if have wtype; then type_cmd="wtype"; fi
else
    # X11
    if have xclip; then
        copy_cmd="xclip -selection clipboard"
    elif have xsel; then copy_cmd="xsel -b -i"; fi
    if have xdotool; then type_cmd="xdotool type --clearmodifiers --delay 0"; fi
fi
# ---------------------------------------------------

ensure_data() {
    mkdir -p "$CACHE_DIR"
    if [[ "${1:-}" == "--update" || ! -s "$JSON" ]]; then
        curl -fsSL "$EMOJIBASE_URL" -o "$JSON"
    fi
    # TSV columns: emoji \t UPPER_LABEL \t "#tag #tag ..."
    if [[ ! -s "$TSV" || "$JSON" -nt "$TSV" ]]; then
        jq -r '.[] | [.emoji, (.label | ascii_upcase), ((.tags // []) | map("#"+.) | join(" "))] | @tsv' \
            <"$JSON" >"$TSV"
    fi
}

build_rows() {
    # One pretty line per item (no tabbed columns = no jitter)
    # <big emoji>  LABEL — small #tags
    awk -F'\t' 'NF{
    e=$1; n=$2; k=$3;
    gsub(/&/,"&amp;",e); gsub(/</,"&lt;",e); gsub(/>/,"&gt;",e);
    gsub(/&/,"&amp;",n); gsub(/</,"&lt;",n); gsub(/>/,"&gt;",n);
    gsub(/&/,"&amp;",k); gsub(/</,"&lt;",k); gsub(/>/,"&gt;",k);
    printf("<span font=\"15\">%s</span>  %s — <small>%s</small>\n", e, n, k)
  }' "$TSV"
}

pick_with_rofi() {
    local choice code
    choice="$(
        build_rows |
            rofi -dmenu -i -markup-rows \
                -p "emoji" \
                -show-icons false \
                -theme-str "element{padding:6px;} element-icon{size:0;}"
    )"
    code=$?
    [[ -z "${choice:-}" ]] && exit 0

    # Strip markup → "EMOJI  LABEL — TAGS"
    local plain label emoji
    plain="$(sed -E 's|<[^>]+>||g' <<<"$choice")"
    label="$(sed -E 's/^[^ ]+[ ]{2}//' <<<"$plain" | awk -F" — " '{print $1; exit}')"

    # Map LABEL → emoji via TSV
    emoji="$(awk -F'\t' -v L="$label" 'toupper($2)==toupper(L){print $1; exit}' "$TSV")"
    [[ -z "$emoji" ]] && emoji="$(awk '{print $1; exit}' <<<"$plain")"

    do_copy() { [[ -n "$copy_cmd" ]] && eval "$copy_cmd" <<<"$emoji"; }
    do_type() { [[ -n "$type_cmd" ]] && eval "$type_cmd" -- "$emoji"; }

    case "$code" in
    0) do_copy ;;  # Enter: copy
    10) do_type ;; # Alt+1: type
    11)
        do_copy
        do_type
        ;; # Alt+2: copy + type
    *) exit 0 ;;
    esac
}

main() {
    ensure_data "${1:-}"
    pick_with_rofi
}
main "$@"
