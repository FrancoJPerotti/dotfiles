#!/usr/bin/env bash
# set -euo pipefail

# ---------------- paths & config ----------------
DOTS="$HOME/dotfiles"
ENGINES_FILE="$DOTS/scripts/.local/bin/websearch.lst"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-websearch"
mkdir -p "$CACHE_DIR"

WEBAPPS_DIRS=("$HOME/.local/share/applications")

VIVALDI_BIN="${VIVALDI_BIN:-/opt/vivaldi/vivaldi}"

# ---------------- tiny helpers ----------------
die() {
    printf "websearch: %s\n" "$*" >&2
    exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || die "$1 is required"; }

need rofi
need xdotool
need wmctrl

[[ -f "$ENGINES_FILE" ]] || die "engines file not found: $ENGINES_FILE"

# ---------------- rofi look ----------------
ROFI_BASE=(rofi -dmenu -i -p "󰜏 search"
    -show-icons false
    -font "JetBrainsMono Nerd Font 12"
    -kb-cancel "Escape,Super+Shift+Return"
    -theme-str ' element { padding: 6px; } element-icon { size: 0; }'
)

# ---------------- utils ----------------
urlencode() {
    if have jq; then
        jq -sRr @uri <<<"$*"
    else python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$*"; fi
}
host_of() { sed -nE 's#^[a-zA-Z][a-zA-Z0-9+.-]*://([^/]+).*#\1#p' <<<"$1" | tr '[:upper:]' '[:lower:]'; }
strip_www() { sed -E 's#^www\.##i' <<<"$1"; }

# ---------------- engines cache ----------------
declare -A URL NAME ICON
declare -a ORDER
EDC="$CACHE_DIR/engines_data.tsv"
EMC="$CACHE_DIR/engines_menu.tsv"

rebuild_engines_cache() {
    : >"$EDC"
    : >"$EMC"
    ORDER=()
    NAME=()
    URL=()
    ICON=()

    local cleaned
    cleaned="$(
        sed -E '
      s/^[[:space:]]*[*-]?[[:space:]]*//;   # drop optional bullet like "* "
      s/[[:space:]]*$//;                    # rtrim
      s/[[:space:]]*\|[[:space:]]*/|/g      # normalize
    ' "$ENGINES_FILE"
    )"

    while IFS='|' read -r icon alias display_name base_url || [[ -n "${alias:-}" ]]; do
        [[ -z "${alias:-}" || "$alias" =~ ^# || -z "${base_url:-}" ]] && continue
        # trim fields
        for v in icon alias display_name base_url; do
            eval "$v=\"\${$v#\${$v%%[![:space:]]*}}\""
            eval "$v=\"\${$v%\${$v##*[![:space:]]}}\""
        done
        local dn="${display_name:-$alias}"

        URL["$alias"]="$base_url"
        NAME["$alias"]="$dn"
        ICON["$alias"]="${icon:-·}"
        ORDER+=("$alias")

        printf "%s\t%s\t%s\t%s\n" "$alias" "${ICON[$alias]}" "$dn" "$base_url" >>"$EDC"
        printf "%s  %s — %s\n" "${ICON[$alias]}" "$dn" "$alias" >>"$EMC"
    done <<<"$cleaned"
}

load_engines() {
    local sigf="$CACHE_DIR/engines.sig" new old
    new="$(cksum "$ENGINES_FILE" | awk '{print $1"-"$2}')"
    old="$(cat "$sigf" 2>/dev/null || true)"
    if [[ "$new" == "$old" && -s "$EDC" && -s "$EMC" ]]; then
        while IFS=$'\t' read -r alias icon name base; do
            [[ -z "$alias" ]] && continue
            ORDER+=("$alias")
            NAME["$alias"]="$name"
            URL["$alias"]="$base"
            ICON["$alias"]="$icon"
        done <"$EDC"
    else
        rebuild_engines_cache
        echo -n "$new" >"$sigf"
    fi
    [[ ${#ORDER[@]} -gt 0 ]] || die "no valid engines in $ENGINES_FILE"
}

# ---------------- web apps cache ----------------
WAC="$CACHE_DIR/webapps_cache.txt"
WAS="$CACHE_DIR/webapps_dirs.sig"

rebuild_webapps_cache() {
    : >"$WAC"
    shopt -s nullglob
    for d in "${WEBAPPS_DIRS[@]}"; do
        for f in "$d"/*.desktop; do
            local name="" appurl=""
            while IFS='=' read -r k v || [[ -n "$k" ]]; do
                case "$k" in
                Name) [[ -z "$name" ]] && name="$v" ;;
                Exec) [[ "$v" =~ --app=([^[:space:]]+) ]] && appurl="${BASH_REMATCH[1]}" ;;
                esac
                [[ -n "$name" && -n "$appurl" ]] && break
            done <"$f"
            if [[ -n "$appurl" ]]; then
                local host
                host="$(strip_www "$(host_of "$appurl")")"
                [[ -n "$host" ]] && printf "%s|%s\n" "$host" "${name:-$host}" >>"$WAC"
            fi
        done
    done
}

ensure_webapps_cache() {
    local sig old
    sig="$( (
        for d in "${WEBAPPS_DIRS[@]}"; do find "$d" -maxdepth 1 -type f -name '*.desktop' -printf '%p %T@\n' 2>/dev/null; done
        printf 'END\n'
    ) | cksum | awk '{print $1}')"
    old="$(cat "$WAS" 2>/dev/null || true)"
    if [[ "$sig" != "$old" || ! -s "$WAC" ]]; then
        rebuild_webapps_cache
        echo -n "$sig" >"$WAS"
    fi
}
webapp_name_for_host() { grep -m1 -E "^${1//./\\.}\|" "$WAC" | cut -d'|' -f2- || true; }

# ---------------- window introspection & control ----------------
_list_vivaldi_wids_decimal() {
    wmctrl -lx 2>/dev/null | grep 'Vivaldi-stable' | awk '{print $1}' | while read -r wid_hex; do printf "%d\n" "$wid_hex"; done
}
_pick_best_browser_window() {
    local target_wid_hex
    target_wid_hex=$(wmctrl -lx 2>/dev/null | awk '$3 == "vivaldi-stable.Vivaldi-stable" {print $1; exit}')
    [[ -n "$target_wid_hex" ]] && {
        printf "%d\n" "$target_wid_hex"
        return 0
    }
    return 1
}
_find_new_vivaldi_wid() {
    local cmd_to_run="$1"
    local before_wids after_wids new_wid deadline
    before_wids=$(_list_vivaldi_wids_decimal | sort)
    eval "$cmd_to_run"
    deadline=$((SECONDS + 5))
    while ((SECONDS < deadline)); do
        after_wids=$(_list_vivaldi_wids_decimal | sort)
        new_wid=$(comm -13 <(echo "$before_wids") <(echo "$after_wids") | head -n1)
        [[ -n "$new_wid" ]] && {
            echo "$new_wid"
            return 0
        }
        sleep 0.2
    done
    return 1
}
_focus_wid_forcefully() {
    local wid_to_focus="${1:-}"
    [[ -z "$wid_to_focus" ]] && return 1
    local wid_hex target_desktop current_desktop deadline current_active_wid
    wid_hex=$(printf "0x%08x" "$wid_to_focus")
    target_desktop=$(wmctrl -l 2>/dev/null | awk -v w="$wid_hex" '$1==w {print $2}')
    if [[ -n "$target_desktop" && "$target_desktop" != "-1" ]]; then
        current_desktop=$(wmctrl -d | awk '/\*/{print $1}')
        [[ "$current_desktop" != "$target_desktop" ]] && {
            wmctrl -s "$target_desktop"
            sleep 0.2
        }
    fi
    deadline=$((SECONDS + 3))
    while ((SECONDS < deadline)); do
        xdotool windowactivate "$wid_to_focus"
        sleep 0.05
        current_active_wid="$(xdotool getactivewindow 2>/dev/null || true)"
        [[ "$current_active_wid" == "$wid_to_focus" ]] && return 0
        sleep 0.1
    done
    return 1
}

# ---------------- history & ui ----------------
remember_engine() {
    local a="$1" f="$CACHE_DIR/recent.sites"
    {
        printf "%s\n" "$a"
        cat "$f" 2>/dev/null
    } | awk 'NF && !seen[$0]++' >"$f.tmp" && mv "$f.tmp" "$f"
}
remember_query() {
    local a="$1" q="$2" f="$CACHE_DIR/${a}.txt"
    {
        printf "%s\n" "$q"
        cat "$f" 2>/dev/null
    } | awk 'NF && !seen[$0]++' >"$f.tmp" && mv "$f.tmp" "$f"
}
engine_picker() { cat "$EMC" | "${ROFI_BASE[@]}"; }
query_prompt() {
    local a="$1" f="$CACHE_DIR/${a}.txt"
    touch "$f"
    "${ROFI_BASE[@]}" -p "${NAME[$a]} → query" <"$f"
}

# ---------------- pipeline ----------------
perform_search() {
    local a="$1"
    shift
    local query="${*:-}"
    [[ -n "${URL[$a]:-}" ]] || die "unknown alias: $a"
    remember_engine "$a"

    local base="${URL[$a]}" final enc
    if [[ -z "$query" ]]; then
        final="$base"
    else
        remember_query "$a" "$query"
        enc="$(urlencode "$query")"
        if [[ "$base" == *"{q}"* ]]; then final="${base//\{q\}/$enc}"; else final="${base}${enc}"; fi
    fi

    ensure_webapps_cache
    local host_raw app_name
    host_raw="$(strip_www "$(host_of "$base")")"
    app_name="$(webapp_name_for_host "$host_raw" || true)"

    if [[ -n "$app_name" ]]; then
        # Let i3 handle workspace assignment + tabbed layout via your existing rules.
        setsid -f "$VIVALDI_BIN" --app="$final" >/dev/null 2>&1 &
        # No focusing/moving here on purpose.
    else
        local target_wid
        target_wid="$(_pick_best_browser_window || true)"
        if [[ -n "$target_wid" ]]; then
            setsid -f "$VIVALDI_BIN" --new-tab "$final" >/dev/null 2>&1 &
            sleep 0.2
            _focus_wid_forcefully "$target_wid"
        else
            if pidof vivaldi vivaldi-bin >/dev/null 2>&1; then
                local new_wid
                new_wid="$(_find_new_vivaldi_wid "setsid -f \"$VIVALDI_BIN\" --new-tab '$final' >/dev/null 2>&1" || true)"
                [[ -n "$new_wid" ]] && _focus_wid_forcefully "$new_wid"
            else
                local new_wid
                new_wid="$(_find_new_vivaldi_wid "setsid -f \"$VIVALDI_BIN\" --new-window '$final' >/dev/null 2>&1" || true)"
                [[ -n "$new_wid" ]] && _focus_wid_forcefully "$new_wid"
            fi
        fi
    fi
}

# ---------------- main ----------------
load_engines
ensure_webapps_cache

INPUT="$(engine_picker)" || exit 0
[[ -z "${INPUT:-}" ]] && exit 0

if [[ "$INPUT" == *" "* ]]; then
    alias_typed="${INPUT%% *}"
    if [[ -n "${URL[$alias_typed]:-}" ]]; then
        perform_search "$alias_typed" "${INPUT#* }"
        exit 0
    fi
fi

alias_picked="${INPUT##* — }"
if [[ -z "${URL[$alias_picked]:-}" ]]; then
    perform_search "${ORDER[0]}" "$INPUT"
    exit 0
fi

QUERY="$(query_prompt "$alias_picked")" || exit 0
perform_search "$alias_picked" "$QUERY"
