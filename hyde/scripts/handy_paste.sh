#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )); then
    printf 'Usage: %s TEXT\n' "${0##*/}" >&2
    exit 64
fi

for dependency in hyprctl jq wl-copy wl-paste wtype; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf 'handy_paste: required command not found: %s\n' "$dependency" >&2
        exit 127
    fi
done

text="$1"
# A sentinel keeps command substitution from stripping trailing newlines.
sanitized_text="$(printf '%s' "$text" | tr -d '\000-\010\013\014\016-\037\177'; printf '.')"
sanitized_text="${sanitized_text%.}"

# Handy passes the current transcript as $1. Copy the cleaned value first so the
# paste keystroke always uses the latest dictated text instead of stale clipboard
# history. Strip hidden control characters to avoid terminal paste warnings.
if ! wl-copy --type "text/plain;charset=utf-8" -- "$sanitized_text" >/dev/null 2>&1; then
    printf 'handy_paste: failed to copy transcript to the Wayland clipboard\n' >&2
    exit 1
fi

# wl-copy becomes the selection owner asynchronously. Wait until consumers can
# actually read the new value instead of relying on a fixed delay.
clipboard_ready=false
for _ in {1..40}; do
    if clipboard_text="$(wl-paste --no-newline 2>/dev/null && printf '.')" \
        && [[ "${clipboard_text%.}" == "$sanitized_text" ]]; then
        clipboard_ready=true
        break
    fi
    sleep 0.01
done

if [[ "$clipboard_ready" != true ]]; then
    printf 'handy_paste: timed out waiting for the Wayland clipboard\n' >&2
    exit 1
fi

# Choose the paste shortcut for the window focused when the text is ready.
if ! active_class="$(hyprctl -j activewindow 2>/dev/null | jq -er '.class | select(type == "string" and length > 0) | ascii_downcase')"; then
    printf 'handy_paste: text copied, but could not determine the focused application; paste manually\n' >&2
    exit 1
fi

paste_failed() {
    printf 'handy_paste: text copied, but sending the paste shortcut failed; paste manually\n' >&2
    exit 1
}

case "$active_class" in
term | terminal | *kitty* | *wezterm* | *alacritty* | foot | *ghostty* | *gnome-terminal* | *kgx* | *konsole* | *xterm* | nvim | neovim)
    # Target the focused terminal directly. Sending the shortcut through
    # wtype's virtual keyboard can translate V as W with remapped layouts,
    # which triggers Kitty's close-window confirmation instead of paste.
    hyprctl eval '
        local window = assert(hl.get_active_window(), "no active window")
        hl.dispatch(hl.dsp.send_key_state({
            mods = "CTRL SHIFT",
            key = "code:55",
            state = "down",
            window = window,
        }))
        hl.dispatch(hl.dsp.send_key_state({
            mods = "CTRL SHIFT",
            key = "code:55",
            state = "up",
            window = window,
        }))
    ' >/dev/null || paste_failed
    ;;
*)
    # GUI apps usually expect Ctrl+V.
    wtype -M ctrl -k v -m ctrl || paste_failed
    ;;
esac
