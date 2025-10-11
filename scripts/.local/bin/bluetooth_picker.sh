#!/usr/bin/env bash
# rofi-bluetooth --- manage Bluetooth devices via rofi + bluetoothctl
# Requirements: bluetoothctl (BlueZ), rofi, notify-send
# Optional: rfkill (for hard block checks)

set -Eeuo pipefail

# One place to control your rofi theme/flags (dmenu mode)
ROFI=(rofi -dmenu -i -markup-rows -p "  bluetooth"
    -show-icons false
    # -theme "$HOME/.config/rofi/yourtheme.rasi"
    -theme-str ' element { padding: 6px; } element-icon { size: 0; }'
)

NOTIFY="notify-send -u normal -t 3000"
die() { $NOTIFY "Bluetooth" "Error: $*" && exit 1; }

command -v bluetoothctl >/dev/null 2>&1 || die "bluetoothctl not found (install bluez)."
command -v rofi >/dev/null 2>&1 || die "rofi not found."
command -v notify-send >/dev/null 2>&1 || NOTIFY="echo"

bt() { bluetoothctl "$@" </dev/null; } # avoid interactive hangs

# ----- Helpers -----
bt_power_state() {
    bt show | awk -F': ' '/Powered:/{print $2; exit}'
}

active_adapter() {
    bt list | sed -n 's/^Controller \([0-9A-F:]\+\) .*/\1/p' | head -n1
}

any_connected() {
    # Returns "yes" if any device is connected
    bt devices | sed -n 's/^Device \([0-9A-F:]\+\) .*/\1/p' |
        while read -r mac; do bt info "$mac" | grep -q "Connected: yes" && {
            echo yes
            break
        }; done
}

device_is_paired() {
    local mac="$1"
    bt paired-devices | grep -q "Device $mac "
}

device_is_connected() {
    local mac="$1"
    bt info "$mac" | grep -q "Connected: yes"
}

device_name() {
    local mac="$1"
    bt info "$mac" | awk -F': ' '/Name:/{print substr($0,index($0,$2)) ; exit}'
}

device_rssi() {
    local mac="$1"
    bt info "$mac" | awk -F': ' '/RSSI:/{print $2; exit}'
}

scan_quick() {
    # Prefer --timeout if supported (BlueZ >= 5.64). Fallback to manual.
    if bt --help 2>&1 | grep -q -- '--timeout'; then
        bt --timeout 5 scan on >/dev/null 2>&1 || true
    else
        bt scan on >/dev/null 2>&1 || true
        sleep 5
        bt scan off >/dev/null 2>&1 || true
    fi
}

# Themed status panel
show_status_menu() {
    local powered adapter conn
    powered="$(bt_power_state)"
    adapter="$(active_adapter)"
    conn="$(any_connected || true)"
    [[ -z "$adapter" ]] && adapter="—"
    [[ -z "$conn" ]] && conn="no"

    printf "<b>Powered:</b> %s\n" "${powered:-unknown}"
    printf "<b>Adapter:</b> %s\n" "${adapter}"
    printf "<b>Any connected:</b> %s\n" "${conn}"
    printf "Close\n"
}

# Build menu: actions + devices (paired first, then others)
build_menu() {
    local entries=()
    declare -A seen=()

    local powered current_icon
    powered="$(bt_power_state)"
    if [[ "$powered" == "yes" ]]; then current_icon=" on"; else current_icon=" off"; fi

    entries+=("  Toggle Bluetooth ($current_icon)")
    entries+=("  Scan (5s)")
    entries+=("  Status")
    entries+=("󰌺  Disconnect all")

    # Collect devices
    mapfile -t all_macs < <(bt devices | sed -n 's/^Device \([0-9A-F:]\+\) .*/\1/p')
    mapfile -t paired_macs < <(bt paired-devices | sed -n 's/^Device \([0-9A-F:]\+\) .*/\1/p')

    # Helper to add device entries with badges
    add_device_entry() {
        local mac="$1"
        [[ -n "${seen["$mac"]+x}" ]] && return 0
        seen["$mac"]=1

        local name tags="" rssi=""
        name="$(device_name "$mac")"
        [[ -z "$name" ]] && name="$mac"

        if device_is_paired "$mac"; then tags="[paired]"; fi
        if device_is_connected "$mac"; then tags="[connected] ${tags}"; fi

        rssi="$(device_rssi "$mac" || true)"
        local sig=""
        if [[ -n "$rssi" ]]; then
            # Very rough RSSI buckets
            if ((rssi >= -60)); then
                sig="(Excellent ${rssi} dBm)"
            elif ((rssi >= -70)); then
                sig="(Good ${rssi} dBm)"
            elif ((rssi >= -80)); then
                sig="(Weak ${rssi} dBm)"
            else
                sig="(Very weak ${rssi} dBm)"
            fi
        fi

        entries+=("${name} ${tags} ${sig}  (${mac})")
    }

    # Paired first
    for mac in "${paired_macs[@]}"; do
        [[ -z "$mac" ]] && continue
        add_device_entry "$mac"
    done
    # Then all others (known / recently seen)
    for mac in "${all_macs[@]}"; do
        [[ -z "$mac" ]] && continue
        add_device_entry "$mac"
    done

    printf "%s\n" "${entries[@]}"
}

# ----- Main menu -----
choice=$(build_menu | "${ROFI[@]}")
[[ -z "$choice" ]] && exit 0

case "$choice" in
*"Toggle Bluetooth"*)
    if [[ "$(bt_power_state)" == "yes" ]]; then
        bt power off && $NOTIFY "Bluetooth" "Bluetooth powered off."
    else
        bt power on && $NOTIFY "Bluetooth" "Bluetooth powered on."
    fi
    exit 0
    ;;
*"Scan (5s)"*)
    $NOTIFY "Bluetooth" "Scanning for 5s…"
    scan_quick
    # Rofi dmenu can't auto-refresh itself; just exit. Bind your launcher to reopen.
    exit 0
    ;;
*"Status"*)
    show_status_menu | "${ROFI[@]}" -p "  status" -lines 6 -width 60 >/dev/null
    exit 0
    ;;
*"Disconnect all"*)
    # Disconnect every connected device
    mapfile -t macs < <(bt devices | sed -n 's/^Device \([0-9A-F:]\+\) .*/\1/p')
    for mac in "${macs[@]}"; do
        device_is_connected "$mac" && bt disconnect "$mac" >/dev/null 2>&1 || true
    done
    $NOTIFY "Bluetooth" "Disconnected all devices."
    exit 0
    ;;
*)
    # Extract MAC in parentheses at end of line
    mac=$(printf "%s" "$choice" | sed -n 's/.*(\([0-9A-F:]\{17\}\)).*/\1/p')
    name=$(printf "%s" "$choice" | sed -E 's/\s+\[connected\]//; s/\s+\[paired\]//; s/\s+\(.*$//; s/^\s+|\s+$//g')
    ;;
esac

[[ -z "${mac:-}" ]] && die "No device selected."

# ----- Device action: smart toggle connect/pair -----
if device_is_connected "$mac"; then
    bt disconnect "$mac" >/dev/null 2>&1 && $NOTIFY "Bluetooth" "Disconnected: $name"
    exit 0
fi

# If not paired, try to pair, trust, then connect
if ! device_is_paired "$mac"; then
    $NOTIFY "Bluetooth" "Pairing with: $name"
    # Make sure an agent exists to handle passkeys
    bt agent NoInputNoOutput >/dev/null 2>&1 || true
    bt default-agent >/dev/null 2>&1 || true

    if bt pair "$mac" >/dev/null 2>&1; then
        bt trust "$mac" >/dev/null 2>&1 || true
    else
        $NOTIFY "Bluetooth" "Failed to pair with $name"
        exit 1
    fi
fi

$NOTIFY "Bluetooth" "Connecting to: $name"
if bt connect "$mac" >/dev/null 2>&1; then
    $NOTIFY "Bluetooth" "Connected to $name"
    exit 0
else
    $NOTIFY "Bluetooth" "Failed to connect to $name"
    exit 1
fi
