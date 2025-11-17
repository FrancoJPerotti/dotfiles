#!/usr/bin/env bash
# rofi-wifi --- connect to Wi-Fi networks via rofi + nmcli
# Requirements: nmcli, rofi, notify-send

set -Eeuo pipefail

# One place to control your rofi theme/flags (dmenu mode)
ROFI=(rofi -dmenu -i -markup-rows -p "  wifi"
    -show-icons false
    # Uncomment if your theme file should be forced:
    # -theme "$HOME/.config/rofi/yourtheme.rasi"
    -theme-str ' element { padding: 6px; } element-icon { size: 0; }'
)

NOTIFY="notify-send -u normal -t 3000"
die() { $NOTIFY "Wi-Fi" "Error: $*" && exit 1; }

command -v nmcli >/dev/null 2>&1 || die "nmcli not found. Install NetworkManager."
command -v rofi >/dev/null 2>&1 || die "rofi not found."
command -v notify-send >/dev/null 2>&1 || NOTIFY="echo"

# ----- Helpers -----
active_ssid() {
    nmcli -t -f ACTIVE,SSID device wifi | awk -F: '$1=="yes"{print $2; exit}'
}

active_wifi_dev() {
    # pick connected wifi device if present; else first wifi device
    nmcli -t -f DEVICE,TYPE,STATE device status |
        awk -F: '$2=="wifi" && $3=="connected"{print $1; found=1; exit} END{if(!found){system("")}}'
}

show_status_menu() {
    local wifi_state ssid signal dev ip
    wifi_state=$(nmcli -t -f WIFI g | cut -d: -f2)
    ssid=$(active_ssid)
    signal=$(nmcli -t -f ACTIVE,SIGNAL device wifi | awk -F: '$1=="yes"{print $2; exit}')

    # device & IP (this avoids the invalid IP4.ADDRESS field on --active)
    dev=$(nmcli -t -f DEVICE,TYPE,STATE device status | awk -F: '$2=="wifi"{print $1" ("$3")"; exit}')
    local dev_name
    dev_name=$(printf "%s" "$dev" | awk '{print $1}')

    ip=$(nmcli -t -f IP4.ADDRESS device show "$dev_name" 2>/dev/null | awk -F: 'NR==1{print $2}')
    ip=${ip:-—}

    printf "<b>Wi-Fi:</b> %s\n" "${wifi_state:-unknown}"
    printf "<b>SSID:</b> %s\n" "${ssid:-—}"
    printf "<b>Signal:</b> %s%%\n" "${signal:-—}"
    printf "<b>Device:</b> %s\n" "${dev:-—}"
    printf "<b>IP:</b> %s\n" "${ip}"
    printf "Close\n"
}

# Build list: actions + visible networks + saved markers
build_menu() {
    local entries=()
    declare -A seen=()
    local current
    current="$(active_ssid)"

    entries+=("  Toggle Wi-Fi")
    entries+=("󰌺  Disconnect")
    entries+=("  Status")

    mapfile -t raw < <(nmcli -t -f SSID,SECURITY,SIGNAL device wifi list 2>/dev/null | sed '/^$/d')
    mapfile -t saved_all < <(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2=="802-11-wireless"{print $1}')

    for line in "${raw[@]}"; do
        IFS=':' read -r ssid security signal <<<"$line"
        [[ -z "$ssid" ]] && continue
        if [[ ${seen["$ssid"]+x} ]]; then continue; fi
        seen["$ssid"]=1

        local tag=""
        for s in "${saved_all[@]}"; do
            [[ "$s" == "$ssid" ]] && tag="[saved]" && break
        done
        [[ -n "$current" && "$ssid" == "$current" ]] && tag="[connected] ${tag}"

        local sig_desc
        if ((signal >= 75)); then
            sig_desc="(Excellent ${signal}%)"
        elif ((signal >= 50)); then
            sig_desc="(Good ${signal}%)"
        elif ((signal >= 25)); then
            sig_desc="(Weak ${signal}%)"
        else
            sig_desc="(Very weak ${signal}%)"
        fi

        local sec=""
        [[ -n "$security" && "$security" != "--" ]] && sec="🔒"

        entries+=("${ssid} ${tag} ${sig_desc} ${sec}")
    done

    printf "%s\n" "${entries[@]}"
}

# ----- Main menu -----
choice=$(build_menu | "${ROFI[@]}")
[[ -z "$choice" ]] && exit 0

case "$choice" in
*"Toggle Wi-Fi"*)
    if [[ "$(nmcli -t -f WIFI g | cut -d: -f2)" == "enabled" ]]; then
        nmcli radio wifi off && $NOTIFY "Wi-Fi" "Wi-Fi turned off."
    else
        nmcli radio wifi on && $NOTIFY "Wi-Fi" "Wi-Fi turned on."
    fi
    exit 0
    ;;
*"Disconnect"*)
    dev=$(active_wifi_dev)
    if [[ -z "$dev" ]]; then
        $NOTIFY "Wi-Fi" "No Wi-Fi device found."
        exit 0
    fi
    if nmcli device disconnect "$dev"; then
        $NOTIFY "Wi-Fi" "Disconnected $dev."
    else
        $NOTIFY "Wi-Fi" "Failed to disconnect."
    fi
    exit 0
    ;;
*"Status"*)
    show_status_menu | "${ROFI[@]}" -p "  status" -lines 7 -width 60 >/dev/null
    exit 0
    ;;
*)
    # Extract SSID only (strip badges + signal text)
    ssid=$(printf "%s" "$choice" | sed -E 's/\s+\[connected\]\s*//; s/\s+\[saved\]\s*//; s/\s+\(.*$//')
    ssid=$(echo -n "$ssid" | sed -E 's/^\s+|\s+$//g')
    ;;
esac

[[ -z "$ssid" ]] && die "No SSID selected."

# ----- Connect logic -----
conn_exists=$(nmcli -t -f NAME,TYPE connection show | awk -F: -v s="$ssid" '$1==s && $2=="802-11-wireless"{print "yes"}')

if [[ "$conn_exists" == "yes" ]]; then
    $NOTIFY "Wi-Fi" "Connecting to saved network: $ssid"
    if nmcli connection up "$ssid" >/dev/null 2>&1; then
        $NOTIFY "Wi-Fi" "Connected to $ssid"
        exit 0
    else
        $NOTIFY "Wi-Fi" "Failed to use saved connection, trying new..."
    fi
fi

sec=$(nmcli -t -f SSID,SECURITY device wifi list | awk -F: -v s="$ssid" '$1==s{print $2; exit}')

if [[ -z "$sec" || "$sec" == "--" ]]; then
    $NOTIFY "Wi-Fi" "Connecting to open network: $ssid"
    if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
        $NOTIFY "Wi-Fi" "Connected to $ssid (open)"
        exit 0
    else
        die "Failed to connect to $ssid (open)"
    fi
else
    # Themed password prompt
    pass=$("${ROFI[@]}" -password -p "Password for: $ssid" -lines 0 -width 40)
    [[ -z "$pass" ]] && $NOTIFY "Wi-Fi" "Cancelled" && exit 0
    $NOTIFY "Wi-Fi" "Connecting to $ssid..."
    if nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
        $NOTIFY "Wi-Fi" "Connected to $ssid"
        exit 0
    else
        $NOTIFY "Wi-Fi" "Failed to connect to $ssid (wrong password?)"
        exit 1
    fi
fi
