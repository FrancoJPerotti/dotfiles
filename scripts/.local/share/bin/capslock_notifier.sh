#!/usr/bin/env bash

LOG=/tmp/capslock_alert.log
>"$LOG"

keyboard_dev=$(find /dev/input/by-id/ -type l -name '*-kbd' -exec readlink -f {} \; | head -n1)

if [[ -z $keyboard_dev || ! -e $keyboard_dev ]]; then
    echo "$(date) ❌ Cannot find keyboard device" >>"$LOG"
    exit 1
fi

echo "$(date) ✅ Monitoring CAPS LOCK LED on $keyboard_dev" >>"$LOG"

last_state="off"
NOTIF_ID=22222 # Arbitrary ID

evtest "$keyboard_dev" 2>/dev/null | while read -r line; do
    echo "$(date) RAW: $line" >>"$LOG"

    if [[ "$line" == *"EV_LED"* && "$line" == *"LED_CAPSL"* ]]; then
        if [[ "$line" == *"value 1"* && "$last_state" != "on" ]]; then
            last_state="on"
            echo "$(date) CAPS LOCK turned ON" >>"$LOG"
            notify-send -r "$NOTIF_ID" -u critical "🟥 CAPS LOCK ENABLED"
        elif [[ "$line" == *"value 0"* && "$last_state" != "off" ]]; then
            last_state="off"
            echo "$(date) CAPS LOCK turned OFF — closing" >>"$LOG"
            dunstctl close "$NOTIF_ID"
        fi
    fi
done
