#!/usr/bin/env bash
#
# Rofi Web Search (HyDE-styled)
#
# Description:
#   A rofi-based script for quick web searches. It allows defining search engines
#   with aliases, provides a searchable history, and intelligently focuses the
#   browser window (with special integration for Hyprland and Vivaldi).
#
# Features:
#   - Fast startup due to extensive caching of engine data and web app metadata.
#   - Two-step search: Pick an engine, then type a query.
#   - Single-step search: Type "alias query" directly.
#   - History for each search engine.
#   - Seamless integration with Hyprland to focus the correct browser or web-app window.
#   - Theming support to match your desktop look (e.g., HyDE).
#
# Dependencies:
#   - rofi: The menu interface.
#   - bash: For script execution.
#   - Optional:
#     - jq: For efficient JSON parsing (URL encoding, Hyprland client data).
#     - python3: Fallback for URL encoding if jq is not available.
#     - hyprctl: For window focusing on the Hyprland compositor.
#     - vivaldi: The target browser for this script's launch logic.
#
# Exit immediately if a command exits with a non-zero status.
# Exit immediately if a pipeline fails.
# Treat unset variables as an error.
# set -euo pipefail

# --------------------------------------------------------------------------------------
# Configuration
#
# Tweak these variables to match your system setup. They can also be overridden
# by environment variables.
# --------------------------------------------------------------------------------------

# Path to the file defining your search engines.
# Format: icon|alias|display_name|base_url
# Example: |g|Google|https://www.google.com/search?q={q}
ENGINES_FILE="$(dirname "$0")/custom_websearch.lst"

# Directory for storing cache files (engine data, history, etc.).
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyde/websearch"

# Directory where .desktop files for web apps (PWAs) are stored.
WEBAPPS_DIR="${HOME}/.local/share/applications"

# Ensure the cache directory exists.
mkdir -p "$CACHE_DIR"

# --- Browser & Window Management Configuration ---

# Path to the Vivaldi executable.
VIVALDI_BIN="${VIVALDI_BIN:-/opt/vivaldi/vivaldi}"

# Regex to identify Vivaldi windows by their WM_CLASS.
VIVALDI_CLASS_REGEX="${VIVALDI_CLASS_REGEX:-^(vivaldi|vivaldi-stable)$}"

# Timeout for focusing windows (currently unused in this version).
FOCUS_TIMEOUT="${FOCUS_TIMEOUT:-3}"

# Set to "1" to sync Rofi's border style with Hyprland's settings.
ROFI_WEBSEARCH_HYPR_SYNC="${ROFI_WEBSEARCH_HYPR_SYNC:-0}"

# --------------------------------------------------------------------------------------
# HyDE Initialization (Optional)
#
# If the hyde-shell utility is found, initialize it to inherit theme settings.
# --------------------------------------------------------------------------------------
if command -v hyde-shell >/dev/null 2>&1; then
    # Initialize only if it hasn't been done already.
    [[ "${HYDE_SHELL_INIT:-0}" -ne 1 ]] && eval "$(hyde-shell init)"
fi

# --------------------------------------------------------------------------------------
# Rofi Theme Setup
#
# Generates Rofi theme overrides based on environment variables or Hyprland settings
# to create a consistent, styled appearance.
# --------------------------------------------------------------------------------------
setup_rofi_config() {
    # --- Font Configuration ---
    local font_scale="${ROFI_WEBSEARCH_SCALE:-${ROFI_SCALE:-10}}"
    # Ensure font_scale is a valid integer.
    [[ "$font_scale" =~ ^[0-9]+$ ]] || font_scale=10

    local font_name="${ROFI_WEBSEARCH_FONT:-${ROFI_FONT:-}}"
    # If font name is not set, try to get it from Hyprland configuration via `get_hyprConf`.
    if [[ -z "$font_name" ]] && command -v get_hyprConf >/dev/null 2>&1; then
        font_name="$(get_hyprConf "MENU_FONT" "$(get_hyprConf "FONT")")"
    fi
    # Fallback to a default font if none is found.
    font_name="${font_name:-JetBrainsMono Nerd Font}"
    FONT_OVERRIDE="* {font: \"${font_name} ${font_scale}\";}"

    # --- Border and Style Configuration ---
    local wind_border=16 elem_border=10 hypr_width=2
    # If sync is enabled, attempt to fetch border settings directly from Hyprland.
    if [[ "$ROFI_WEBSEARCH_HYPR_SYNC" == "1" ]] && command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local hypr_border
        hypr_border="$(hyprctl -j getoption decoration:rounding | jq '.int' 2>/dev/null || echo 10)"
        hypr_width="$(hyprctl -j getoption general:border_size | jq '.int' 2>/dev/null || echo 2)"
        # Calculate proportional border radii for a pleasant look.
        wind_border=$((hypr_border * 3 / 2))
        elem_border=$((hypr_border == 0 ? 5 : hypr_border))
    fi
    R_OVERRIDE="window{border:${hypr_width}px;border-radius:${wind_border}px;} wallbox{border-radius:${elem_border}px;} element{border-radius:${elem_border}px;}"

    # Set the Rofi theme name.
    ROFI_THEME_NAME="${ROFI_WEBSEARCH_STYLE:-clipboard}"
    # Allow passing extra arguments to Rofi via an environment variable.
    # SC2206: We intentionally want word splitting here.
    # shellcheck disable=SC2206
    ROFI_EXTRA_ARGS=(${ROFI_WEBSEARCH_ARGS-})
}

# --------------------------------------------------------------------------------------
# Utility Functions
# --------------------------------------------------------------------------------------

# Displays an error message using Rofi.
rofi_error() {
    rofi -e "$@" -config "$ROFI_THEME_NAME" -theme-str "$R_OVERRIDE" -theme-str "$FONT_OVERRIDE"
}

# URL-encodes a given string. Prefers `jq` for speed, falls back to `python3`.
urlencode() {
    # SC2015: Use a proper if/else for robustness instead of `&& ||`.
    if command -v jq >/dev/null; then
        # Use jq's raw string input (-R) and URI formatting (@uri).
        jq -sRr @uri <<<"$*"
    else
        # Fallback to Python's urllib.
        python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$*"
    fi
}

# Extracts the host from a URL.
# e.g., "https://www.google.com/search" -> "www.google.com"
host_of() {
    sed -nE 's#^[a-zA-Z][a-zA-Z0-9+.-]*://([^/]+).*#\1#p' <<<"$1" | tr '[:upper:]' '[:lower:]'
}

# Strips the leading "www." from a hostname.
# e.g., "www.google.com" -> "google.com"
strip_www() {
    sed -E 's#^www\.##i' <<<"$1"
}

# --------------------------------------------------------------------------------------
# Search Engine Loading (Cached)
#
# Loads search engine definitions from the ENGINES_FILE. To avoid parsing this
# file on every run, the data is processed and stored in cache files. The cache
# is only rebuilt if the source file changes.
# --------------------------------------------------------------------------------------
# SC2034: The in-memory ICON array was unused and has been removed in a previous refactor.
# This comment is preserved to explain its absence.
declare -A URL NAME
declare -a ORDER
ENGINES_DATA_CACHE="${CACHE_DIR}/engines_data.tsv"
ENGINES_MENU_CACHE="${CACHE_DIR}/engines_menu.tsv"

# Rebuilds the search engine cache from the ENGINES_FILE.
rebuild_engines_cache() {
    # Clear existing cache files and in-memory arrays.
    : >"$ENGINES_DATA_CACHE"
    : >"$ENGINES_MENU_CACHE"
    ORDER=() NAME=() URL=()

    # Pre-process the entire file in one `sed` command to trim all whitespace.
    # This is significantly faster than processing each line individually in the loop.
    local cleaned_engines
    cleaned_engines="$(sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/[[:space:]]*|[[:space:]]*/|/g' "$ENGINES_FILE")"

    # Read the cleaned data line by line.
    while IFS='|' read -r icon alias display_name base_url; do
        # Skip empty lines, comments, or lines without a base URL.
        [[ -z "$alias" || "$alias" =~ ^# || -z "$base_url" ]] && continue

        # Use the alias as the display name if one isn't provided.
        local final_display_name="${display_name:-$alias}"
        URL["$alias"]="$base_url"
        NAME["$alias"]="$final_display_name"
        ORDER+=("$alias")

        # Write to cache files for persistence.
        printf "%s\t%s\t%s\t%s\n" "$alias" "$icon" "$final_display_name" "$base_url" >>"$ENGINES_DATA_CACHE"
        printf "%s\t%s - %s\n" "$icon" "$final_display_name" "$alias" >>"$ENGINES_MENU_CACHE"
    done <<<"$cleaned_engines"
}

# Loads search engines from cache or rebuilds it if the source file has changed.
load_engines() {
    [[ -f "$ENGINES_FILE" ]] || {
        rofi_error "Engines file not found: $ENGINES_FILE"
        exit 1
    }

    # Generate a signature (checksum and size) of the engines file to detect changes.
    local sig_file="${CACHE_DIR}/engines.sig"
    local new_sig old_sig
    new_sig="$(cksum "$ENGINES_FILE" | awk '{print $1"-"$2}')"
    old_sig="$(cat "$sig_file" 2>/dev/null || true)"

    # If the signature matches and the cache exists, load from cache.
    if [[ "$new_sig" == "$old_sig" ]] && [[ -s "$ENGINES_DATA_CACHE" ]]; then
        while IFS=$'\t' read -r alias icon name base; do
            [[ -z "$alias" ]] && continue
            ORDER+=("$alias")
            NAME["$alias"]="$name"
            URL["$alias"]="$base"
        done <"$ENGINES_DATA_CACHE"
    else
        # Otherwise, rebuild the cache and store the new signature.
        rebuild_engines_cache
        echo -n "$new_sig" >"$sig_file"
    fi

    # Ensure at least one search engine was loaded.
    [[ ${#ORDER[@]} -gt 0 ]] || {
        rofi_error "No valid search engines found in $ENGINES_FILE"
        exit 1
    }
}

# --------------------------------------------------------------------------------------
# Hyprland Focus Helpers
#
# These functions handle focusing the correct browser or web-app window after a
# search. They are "lazy" because they are only called after the search is
# performed, not during the Rofi menu drawing phase.
# --------------------------------------------------------------------------------------

# Focuses the most recently used Vivaldi browser window.
hypr_focus_vivaldi_browser() {
    command -v hyprctl >/dev/null || return 0 # Do nothing if not on Hyprland.
    if command -v jq >/dev/null; then
        # Efficiently find the correct window using jq:
        # 1. Get all clients (.[]).
        # 2. Select clients where the class matches the Vivaldi regex.
        # 3. Sort by focusHistoryID (most recent first).
        # 4. Get the address of the top result.
        local addr
        addr="$(hyprctl -j clients | jq -r --argjson regex "\"$VIVALDI_CLASS_REGEX\"" '[ .[] | select(.class | test($regex)) ] | sort_by(.focusHistoryID // 0) | reverse | .[0].address // empty')"
        # If an address was found, focus it.
        [[ -n "$addr" ]] && hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
    else
        # Fallback for systems without jq (less precise).
        hyprctl dispatch focuswindow "class:$VIVALDI_CLASS_REGEX" >/dev/null 2>&1 || true
    fi
}

# --------------------------------------------------------------------------------------
# Web App Index (Cached)
#
# Parses .desktop files to find web apps (PWAs) and caches their metadata.
# This allows the script to identify if a search URL belongs to a known PWA
# and launch it in its own window.
# --------------------------------------------------------------------------------------
WEBAPP_CACHE_TXT="${CACHE_DIR}/webapps_cache.txt"
WEBAPP_DIR_SIG="${CACHE_DIR}/webapps_dir.sig"

# Rebuilds the web app cache by parsing .desktop files.
rebuild_webapps_cache() {
    : >"$WEBAPP_CACHE_TXT"
    # Process all .desktop files; `nullglob` prevents errors if the directory is empty.
    shopt -s nullglob
    for file in "${WEBAPPS_DIR}"/*.desktop; do
        local name="" appurl=""
        # Read the .desktop file line by line to find the Name and Exec keys.
        while IFS='=' read -r key val || [[ -n "$key" ]]; do
            case "$key" in
            Name) [[ -z "$name" ]] && name="$val" ;;
            # Extract the URL from the --app argument in the Exec key.
            Exec) if [[ "$val" =~ --app=([^[:space:]]+) ]]; then appurl="${BASH_REMATCH[1]}"; fi ;;
            esac
            # Stop parsing once we have both pieces of info.
            [[ -n "$name" && -n "$appurl" ]] && break
        done <"$file"
        # If a valid app URL was found, process and cache it.
        if [[ -n "$appurl" ]]; then
            local host
            host="$(strip_www "$(host_of "$appurl")")"
            [[ -n "$host" ]] && printf "%s|%s\n" "$host" "${name:-$host}" >>"$WEBAPP_CACHE_TXT"
        fi
    done
}

# Ensures the web app cache is up-to-date.
ensure_webapps_cache() {
    # Create a signature based on the timestamps of .desktop files.
    # This is a reliable way to detect if files have been added, removed, or changed.
    local sig
    sig="$( (
        find "$WEBAPPS_DIR" -maxdepth 1 -type f -name '*.desktop' -printf '%p %T@\n' 2>/dev/null | sort -k2,2n
        echo "${WEBAPPS_DIR}"
    ) | cksum | awk '{print $1}')"

    local old_sig
    old_sig="$(cat "$WEBAPP_DIR_SIG" 2>/dev/null || true)"
    # If the signature has changed or the cache file is empty, rebuild it.
    if [[ "$sig" != "$old_sig" ]] || [[ ! -s "$WEBAPP_CACHE_TXT" ]]; then
        rebuild_webapps_cache
        echo -n "$sig" >"$WEBAPP_DIR_SIG"
    fi
}

# Finds the display name of a web app given its host.
webapp_name_for_host() {
    # Grep the cache for a line starting with the host and extract the name.
    # The host's dots are escaped to be treated literally by grep.
    grep -m 1 -E "^${1//./\\.}\|" "$WEBAPP_CACHE_TXT" | cut -d'|' -f2-
}

# --------------------------------------------------------------------------------------
# Browser Launchers & History Management
# --------------------------------------------------------------------------------------

# Opens a URL in a new tab in an existing Vivaldi window, or a new window if not running.
open_url_in_vivaldi_newtab() {
    # Check if a Vivaldi process is already running.
    if pidof vivaldi vivaldi-bin >/dev/null 2>&1; then
        # If so, open the URL in a new tab.
        setsid -f "$VIVALDI_BIN" --new-tab "$1" >/dev/null 2>&1 &
    else
        # Otherwise, launch Vivaldi with the URL.
        setsid -f "$VIVALDI_BIN" "$1" >/dev/null 2>&1 &
    fi
}

# Opens a URL as a Vivaldi web app (PWA).
# SC1045: Removed erroneous semicolon after '&' in a previous refactor.
open_url_in_vivaldi_app() {
    setsid -f "$VIVALDI_BIN" --app="$1" >/dev/null 2>&1 &
}

# Adds the selected search engine alias to the top of the recent list.
remember_engine() {
    local alias="$1" history_file="${CACHE_DIR}/recent.sites"
    # Prepend the new alias, then use awk to remove subsequent duplicates, keeping the first occurrence.
    {
        printf "%s\n" "$alias"
        cat "$history_file" 2>/dev/null
    } | awk 'NF && !seen[$0]++' >"$history_file.tmp" && mv "$history_file.tmp" "$history_file"
}

# Adds the typed query to the top of the history for that specific engine.
remember_query() {
    local alias="$1"
    local query="$2"
    local history_file="${CACHE_DIR}/${alias}.txt"
    # Same logic as remember_engine: prepend and filter duplicates.
    {
        printf "%s\n" "$query"
        cat "$history_file" 2>/dev/null
    } | awk 'NF && !seen[$0]++' >"$history_file.tmp" && mv "$history_file.tmp" "$history_file"
}

# --------------------------------------------------------------------------------------
# Rofi UI Screens
# --------------------------------------------------------------------------------------

# Displays the main engine selection screen.
engine_picker_screen() {
    rofi -dmenu -i -p "🔎 engine · or type: alias query" \
        -config "$ROFI_THEME_NAME" -theme-str "$R_OVERRIDE" -theme-str "$FONT_OVERRIDE" \
        -theme-str 'entry { placeholder: "Type alias query  ·  or pick an engine"; }' \
        -theme-str 'window { width: 50%; }' -theme-str 'listview { columns: 3; }' \
        "${ROFI_EXTRA_ARGS[@]}" <"$ENGINES_MENU_CACHE"
}

# Displays the query prompt for a selected search engine.
query_prompt() {
    local alias="$1"
    local history_file="${CACHE_DIR}/${alias}.txt"
    touch "$history_file" # Ensure the history file exists.
    rofi -dmenu -i -p "${NAME[$alias]} → query" \
        -config "$ROFI_THEME_NAME" -theme-str "$R_OVERRIDE" -theme-str "$FONT_OVERRIDE" \
        -theme-str 'entry { placeholder: "🔎 Query..."; }' -theme-str 'window { width: 50%; }' \
        "${ROFI_EXTRA_ARGS[@]}" <"$history_file"
}

# --------------------------------------------------------------------------------------
# Search Execution Pipeline
# --------------------------------------------------------------------------------------

# Performs the actual search, from URL construction to browser launch and focus.
perform_search() {
    local alias="$1"
    shift
    local query="${*:-}"
    # Validate that the alias exists.
    [[ -n "${URL[$alias]:-}" ]] || {
        rofi_error "Unknown alias: $alias"
        exit 1
    }

    remember_engine "$alias"
    local base_url="${URL[$alias]}" final_url

    if [[ -z "$query" ]]; then
        # If there is no query, open the base URL.
        final_url="$base_url"
    else
        # If there is a query, save it to history and construct the final URL.
        remember_query "$alias" "$query"
        local encoded_query
        encoded_query="$(urlencode "$query")"
        if [[ "$base_url" == *"{q}"* ]]; then
            final_url="${base_url//\{q\}/$encoded_query}"
        else
            final_url="${base_url}${encoded_query}"
        fi
    fi

    # Check if this URL corresponds to a known web app.
    ensure_webapps_cache
    local engine_host_raw
    engine_host_raw="$(strip_www "$(host_of "$base_url")")"
    local app_name
    app_name="$(webapp_name_for_host "$engine_host_raw")"

    # Launch in app mode or a new tab, then focus the window.
    if [[ -n "$app_name" ]]; then
        open_url_in_vivaldi_app "$final_url"
    else
        open_url_in_vivaldi_newtab "$final_url"
        hypr_focus_vivaldi_browser
    fi
}

# --------------------------------------------------------------------------------------
# Main Execution Block
# --------------------------------------------------------------------------------------

# Prepare Rofi theme and load search engine data.
setup_rofi_config
load_engines

# Show the engine picker and capture user input. Exit if the user cancels (e.g., with Esc).
INPUT=$(engine_picker_screen) || exit 0
[[ -z "${INPUT:-}" ]] && exit 0

# --- Fast Path ---
# Handle input in the format "alias query" directly from the first screen.
if [[ "$INPUT" == *" "* ]]; then
    alias_typed="${INPUT%% *}"
    # If the first word is a valid alias, perform the search.
    if [[ -n "${URL[$alias_typed]:-}" ]]; then
        perform_search "$alias_typed" "${INPUT#* }"
        exit 0
    fi
fi

# --- Slow Path ---
# The user selected an entry from the list.
# Rofi output is "icon\tdisplay_name - alias", so we extract the alias at the end.
picked_text="${INPUT##*$'\t'}"
alias_picked="${picked_text##* - }"

# If the extracted text is not a valid alias (e.g., user typed text that
# didn't contain a valid alias), treat the entire input as a query for the
# default (first) search engine.
if [[ -z "${URL[$alias_picked]:-}" ]]; then
    perform_search "${ORDER[0]}" "$INPUT"
    exit 0
fi

# A valid engine was picked, so now prompt for the query.
QUERY=$(query_prompt "$alias_picked") || exit 0

# Perform the search. A blank query is valid and will open the engine's homepage.
perform_search "$alias_picked" "$QUERY"
