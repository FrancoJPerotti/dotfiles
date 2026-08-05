#!/usr/bin/env bash
set -euo pipefail

# Trial and manage the VivoBook Kanata profile on i3/X11. There is no timeout:
# the selected profile stays active until --keep or --rollback is requested.

PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"

kanata_bin="${KANATA_BIN:-${HOME}/.local/bin/kanata}"
next_config="${KANATA_NEXT_CONFIG:-${HOME}/.config/kanata/vivobook-x510uq.kbd}"
rollback_config="${KANATA_ROLLBACK_CONFIG:-${HOME}/.config/kanata/colemak-dh-ansi.kbd}"

usage() {
    cat <<'USAGE'
Usage: kanata_trial.sh --check|--start|--keep|--rollback|--status

  --check     Validate both configs without changing the keyboard.
  --start     Start the VivoBook layout as a transient trial.
  --keep      Replace the trial with the persistent kanata.service.
  --rollback  Disable the persistent service and start the legacy config.
  --status    Show the active Kanata process and service states.

Override paths with KANATA_BIN, KANATA_NEXT_CONFIG, or
KANATA_ROLLBACK_CONFIG.
USAGE
}

require_file() {
    [[ -f "$1" ]] || {
        echo "Missing file: $1" >&2
        exit 1
    }
}

validate() {
    [[ -x "${kanata_bin}" ]] || {
        echo "Missing executable: ${kanata_bin}" >&2
        exit 1
    }
    require_file "${next_config}"
    require_file "${rollback_config}"
    "${kanata_bin}" --check -c "${next_config}"
    "${kanata_bin}" --check -c "${rollback_config}"
}

stop_all_kanata() {
    systemctl --user stop \
        kanata.service kanata-trial.service kanata-legacy.service \
        2>/dev/null || true
    pkill -x kanata 2>/dev/null || true
    for _ in {1..30}; do
        pgrep -x kanata >/dev/null 2>&1 || return 0
        sleep 0.1
    done
    echo "Kanata did not stop cleanly." >&2
    return 1
}

start_transient() {
    local unit="$1"
    local config="$2"

    systemd-run --user --quiet --collect \
        --unit="${unit}" \
        --property=Restart=on-failure \
        --property=RestartSec=750ms \
        -- "${kanata_bin}" -c "${config}" -q

    sleep 0.8
    if ! systemctl --user is-active --quiet "${unit}.service"; then
        echo "Kanata failed to start with ${config}." >&2
        journalctl --user -u "${unit}.service" -n 40 --no-pager >&2 || true
        return 1
    fi
}

restore_legacy() {
    setxkbmap us intl
    systemctl --user disable kanata.service 2>/dev/null || true
    stop_all_kanata
    start_transient kanata-legacy "${rollback_config}"
    echo "Legacy keyboard config restored: ${rollback_config}"
}

case "${1:---status}" in
--check)
    validate
    echo "Both Kanata configs are valid. No runtime changes were made."
    ;;
--start)
    validate
    setxkbmap us intl
    stop_all_kanata
    if ! start_transient kanata-trial "${next_config}"; then
        restore_legacy
        exit 1
    fi
    echo "VivoBook keyboard trial is active with no timeout."
    echo "Run '$0 --keep' to persist it or '$0 --rollback' to restore legacy."
    ;;
--keep)
    validate
    setxkbmap us intl
    stop_all_kanata
    systemctl --user daemon-reload
    systemctl --user enable --now kanata.service
    sleep 0.8
    if ! systemctl --user is-active --quiet kanata.service; then
        restore_legacy
        exit 1
    fi
    echo "VivoBook keyboard profile enabled persistently."
    ;;
--rollback)
    validate
    restore_legacy
    ;;
--status)
    pgrep -af 'kanata.*-c' || echo "Kanata is not running."
    for unit in kanata.service kanata-trial.service kanata-legacy.service; do
        printf '%-24s %s\n' "${unit}" "$(systemctl --user is-active "${unit}" 2>/dev/null || true)"
    done
    ;;
--help|-h)
    usage
    ;;
*)
    usage >&2
    exit 2
    ;;
esac
