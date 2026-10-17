# Shared by the Kanata launcher and event watcher. Return 0 for a matching
# keyboard, 1 for none, and 2 if the kernel device list cannot be read.
firmware_keyboard_connected() {
    local policy="${HOME}/.config/kanata/firmware-keyboards.conf"
    local devices="${KANATA_INPUT_DEVICES_FILE:-/proc/bus/input/devices}"
    local hostname host usb_id rest
    [[ -r "${devices}" ]] || return 2
    [[ -r "${policy}" ]] || return 1
    hostname="$(</proc/sys/kernel/hostname)"
    while read -r host usb_id rest; do
        [[ "${host}" == "${hostname}" && "${usb_id}" =~ ^[[:xdigit:]]{4}:[[:xdigit:]]{4}$ ]] || continue
        if awk -v vendor="${usb_id%:*}" -v product="${usb_id#*:}" '
            tolower($0) ~ "vendor=" tolower(vendor) " product=" tolower(product) { found=1 }
            END { exit !found }
        ' "${devices}"; then
            return 0
        fi
    done <"${policy}"
    return 1
}
