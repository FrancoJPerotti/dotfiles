#!/usr/bin/env bash
# Toggle a floating, pinned lyrics window (sptlrx in kitty).
# Window rules for class "lyrics" are declared in ~/.config/hypr/lua/apps.lua

CLASS="lyrics"
W=443
H=227
MARGIN=8

has_lyrics_window() {
    hyprctl clients -j | jq -e --arg c "$CLASS" '.[] | select(.class==$c)' >/dev/null 2>&1
}

if has_lyrics_window; then
    while has_lyrics_window; do
        hyprctl eval "for _,w in ipairs(hl.get_windows({class=\"${CLASS}\"})) do hl.dispatch(hl.dsp.window.close({window=w})) end" >/dev/null 2>&1
        sleep 0.2
    done
    exit 0
fi

kitty --class "$CLASS" -o font_size=15 -o background_opacity=0.7 -e sptlrx -p mpris >/dev/null 2>&1 &
disown

# Enforce geometry deterministically once the window is mapped
for _ in $(seq 1 25); do
    if has_lyrics_window; then
        read -r X Y <<<"$(hyprctl monitors -j | jq -r --argjson w "$W" --argjson h "$H" --argjson m "$MARGIN" \
            '.[] | select(.focused==true) | "\((.x + .width/.scale - $w - $m) | floor) \((.y + .height/.scale - $h - $m) | floor)"')"
        hyprctl eval "for _,w in ipairs(hl.get_windows({class=\"${CLASS}\"})) do hl.dispatch(hl.dsp.window.resize({x=${W},y=${H},window=w})); hl.dispatch(hl.dsp.window.move({x=${X},y=${Y},window=w})) end" >/dev/null 2>&1
        exit 0
    fi
    sleep 0.2
done
