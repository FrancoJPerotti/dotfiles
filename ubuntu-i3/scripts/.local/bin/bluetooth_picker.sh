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

NOTIFY_CMD=(notify-send -u normal -t 3000)

notify() {
    if ! "${NOTIFY_CMD[@]}" "Bluetooth" "$1"; then
        printf 'Bluetooth: %s\n' "$1" >&2
    fi
    return 0
}

die() { notify "Error: $*"; exit 1; }

if ! command -v notify-send >/dev/null 2>&1; then
    NOTIFY_CMD=(echo)
fi

command -v bluetoothctl >/dev/null 2>&1 || die "bluetoothctl not found (install bluez)."
command -v rofi >/dev/null 2>&1 || die "rofi not found."

bt() { bluetoothctl "$@" </dev/null; } # avoid interactive hangs

# ----- Helpers -----
bt_power_state() {
    local state=""
    state=$(bt show 2>/dev/null | awk -F': ' '/Powered:/{print $2; exit}' || true)
    printf '%s\n' "$state"
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

device_is_connected() {
    local mac="$1"
    local info
    info=$(bt info "$mac" 2>/dev/null || true)
    [[ "$info" == *"Connected: yes"* ]]
}

device_is_paired() {
    local mac="$1"
    local info
    info=$(bt info "$mac" 2>/dev/null || true)
    [[ "$info" == *"Paired: yes"* ]]
}

device_name() {
    local mac="$1"
    bt info "$mac" | awk -F': ' '/Name:/{print substr($0,index($0,$2)) ; exit}'
}

device_rssi() {
    local mac="$1"
    bt info "$mac" | awk -F': ' '/RSSI:/{print $2; exit}'
}

ensure_agent() {
    bt agent NoInputNoOutput >/dev/null 2>&1 || true
    bt default-agent >/dev/null 2>&1 || true
}

ensure_powered() {
    if [[ "$(bt_power_state)" != "yes" ]]; then
        bt power on >/dev/null 2>&1 || return 1
        sleep 1
    fi
    return 0
}

wait_until_connected() {
    local mac="$1" tries=0
    while (( tries < 10 )); do
        if device_is_connected "$mac"; then
            return 0
        fi
        sleep 0.5
        ((tries++))
    done
    return 1
}

connect_with_retry() {
    local mac="$1" attempts=0

    ensure_agent
    ensure_powered || return 1
    bt trust "$mac" >/dev/null 2>&1 || true

    if device_is_connected "$mac"; then
        return 0
    fi

    while (( attempts < 3 )); do
        if device_is_connected "$mac"; then
            return 0
        fi

        if bt connect "$mac" >/dev/null 2>&1; then
            if wait_until_connected "$mac"; then
                return 0
            fi
        else
            if wait_until_connected "$mac"; then
                return 0
            fi
        fi

        ((attempts++))
        sleep 1
    done

    return 1
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
        bt power off && notify "Bluetooth powered off."
    else
        bt power on && notify "Bluetooth powered on."
    fi
    exit 0
    ;;
*"Scan (5s)"*)
    notify "Scanning for 5s…"
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
    notify "Disconnected all devices."
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
    bt disconnect "$mac" >/dev/null 2>&1 && notify "Disconnected: $name"
    exit 0
fi

# If not paired, try to pair, trust, then connect
if ! device_is_paired "$mac"; then
    notify "Pairing with: $name"
    ensure_agent

    if ensure_powered && bt pair "$mac" >/dev/null 2>&1; then
        bt trust "$mac" >/dev/null 2>&1 || true
    else
        if device_is_paired "$mac"; then
            notify "Already paired with $name"
        else
            notify "Failed to pair with $name"
            exit 1
        fi
    fi
fi

notify "Connecting to: $name"
if connect_with_retry "$mac"; then
    notify "Connected to $name"
    exit 0
else
    notify "Failed to connect to $name"
    exit 1
fi
