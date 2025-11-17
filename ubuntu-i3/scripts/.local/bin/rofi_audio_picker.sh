#!/usr/bin/env bash
# rofi-audio --- select sound outputs (sinks) and inputs (sources) via rofi.
# Requirements: rofi, and either pactl (PulseAudio/PipeWire) or wpctl (PipeWire), optional notify-send.

# set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

if ! have rofi; then
  die "rofi is required but not found in PATH."
fi

if have notify-send; then
  notify() { notify-send -u low -t 2000 "Audio" "$1"; }
else
  notify() { printf 'Audio: %s\n' "$1"; }
fi

trim_trailing() {
  local str="$1"
  while [[ "$str" == *[[:space:]] ]]; do
    str="${str%?}"
  done
  printf '%s' "$str"
}

run_rofi() {
  local prompt="$1"
  shift
  rofi -dmenu -i -markup-rows -p "$prompt" \
    -show-icons false \
    -theme-str ' element { padding: 6px; }
                 element-icon { size: 0; }' \
    "$@"
}

trim_leading() {
  local str="$1"
  str="${str#"${str%%[![:space:]]*}"}"
  printf '%s' "$str"
}

strip_tree_chars() {
  local str="$1"
  str="${str//│/}"
  str="${str//├/}"
  str="${str//└/}"
  str="${str//─/}"
  str="${str//┌/}"
  str="${str//┐/}"
  str="${str//┬/}"
  str="${str//┤/}"
  str="${str//┴/}"
  str="${str//┼/}"
  str="${str//╰/}"
  str="${str//╯/}"
  str="${str//╭/}"
  str="${str//╮/}"
  str="${str//•/}"
  str="${str//·/}"
  str="${str//−/}"
  str="${str//–/}"
  str="${str//—/}"
  str="${str//↳/}"
  str="${str//→/}"
  str="${str//➔/}"
  str="${str//►/}"
  printf '%s' "$str"
}

rofi_escape() {
  local str="$1"
  str="${str//&/&amp;}"
  str="${str//</&lt;}"
  str="${str//>/&gt;}"
  printf '%s' "$str"
}

PYTHON_BIN=""

if have pactl; then
  AUDIO_BACKEND="pactl"
elif have wpctl; then
  AUDIO_BACKEND="wpctl"
else
  die "pactl or wpctl is required but neither command was found in PATH."
fi

if [[ "$AUDIO_BACKEND" == "wpctl" ]]; then
  if have python3; then
    PYTHON_BIN="python3"
  else
    PYTHON_BIN=""
  fi
fi

if [[ "$AUDIO_BACKEND" == "pactl" ]]; then
  refresh_pactl_defaults() {
    if ! pactl_info="$(pactl info 2>/dev/null)"; then
      die "Failed to query PulseAudio/PipeWire via 'pactl info'. Is the sound server running?"
    fi

    DEFAULT_SINK_NAME="$(printf '%s\n' "$pactl_info" | awk -F': ' '/^Default Sink:/{print $2}')"
    DEFAULT_SOURCE_NAME="$(printf '%s\n' "$pactl_info" | awk -F': ' '/^Default Source:/{print $2}')"
  }

  refresh_pactl_defaults

  list_devices() {
    local type="$1"
    local header=""
    local default_name=""
    case "$type" in
    sink)
      header="Sink"
      default_name="$DEFAULT_SINK_NAME"
      ;;
    source)
      header="Source"
      default_name="$DEFAULT_SOURCE_NAME"
      ;;
    *)
      return 1
      ;;
    esac

    local current_index=""
    local current_name=""
    local current_desc=""

    print_entry() {
      if [[ -n "$current_name" ]]; then
        local desc="${current_desc:-$current_name}"
        local is_default="no"
        [[ -n "$default_name" && "$current_name" == "$default_name" ]] && is_default="yes"
        printf '%s\t%s\t%s\t%s\t%s\n' "$type" "$current_name" "$desc" "$is_default" "$current_index"
      fi
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "$header #"* ]]; then
        print_entry
        current_index="${line#"$header #"}"
        current_name=""
        current_desc=""
        continue
      fi

      local trimmed
      trimmed="$(trim_leading "$line")"
      case "$trimmed" in
      Name:*)
        current_name="${trimmed#Name: }"
        ;;
      Description:*)
        current_desc="${trimmed#Description: }"
        ;;
      esac
    done < <(pactl list "${type}s")

    print_entry
  }

  move_sink_inputs() {
    local target="$1"
    mapfile -t sink_inputs < <(pactl list short sink-inputs 2>/dev/null | awk '{print $1}')
    for input_id in "${sink_inputs[@]}"; do
      [[ -z "$input_id" ]] && continue
      pactl move-sink-input "$input_id" "$target" >/dev/null 2>&1 || true
    done
  }

  move_source_outputs() {
    local target="$1"
    mapfile -t source_outputs < <(pactl list short source-outputs 2>/dev/null | awk '{print $1}')
    for output_id in "${source_outputs[@]}"; do
      [[ -z "$output_id" ]] && continue
      pactl move-source-output "$output_id" "$target" >/dev/null 2>&1 || true
    done
  }

  set_default_device() {
    local type="$1"
    local name="$2"
    local desc="$3"
    [[ -z "$desc" ]] && desc="$name"

    case "$type" in
    sink)
      pactl set-default-sink "$name"
      move_sink_inputs "$name"
      notify "Output set to ${desc}"
      ;;
    source)
      pactl set-default-source "$name"
      move_source_outputs "$name"
      notify "Input set to ${desc}"
      ;;
    esac
  }

  list_audio_cards() {
    local current_card=""
    local card_name=""
    local card_desc=""
    local active_profile=""
    local active_desc=""
    local in_card=0
    local in_profiles=0
    declare -A profile_desc_map=()

    flush_card() {
      if [[ -n "$current_card" ]]; then
        [[ -z "$active_desc" && -n "$active_profile" ]] && active_desc="${profile_desc_map[$active_profile]}"
        local display_desc="${card_desc:-$card_name}"
        printf '%s\t%s\t%s\t%s\t%s\n' "$current_card" "${card_name:-$current_card}" "${display_desc:-Card $current_card}" "$active_profile" "${active_desc:-$active_profile}"
      fi
    }

    while IFS= read -r line; do
      if [[ "$line" =~ ^Card\ #[0-9]+ ]]; then
        flush_card
        current_card="${line#Card #}"
        current_card="${current_card%% *}"
        card_name=""
        card_desc=""
        active_profile=""
        active_desc=""
        profile_desc_map=()
        in_card=1
        in_profiles=0
        continue
      fi

      [[ -n "$current_card" ]] || continue

      local trimmed
      trimmed="$(trim_leading "$line")"

      if [[ "$trimmed" =~ ^Name:\ (.+)$ ]]; then
        card_name="${BASH_REMATCH[1]}"
        continue
      fi

      if [[ "$trimmed" =~ device.description\ =\ \"(.*)\" ]]; then
        card_desc="${BASH_REMATCH[1]}"
        continue
      fi

      if [[ "$trimmed" =~ ^Profiles: ]]; then
        in_profiles=1
        continue
      fi

      if ((in_profiles)); then
        if [[ "$trimmed" =~ ^Active\ Profile: ]]; then
          in_profiles=0
          active_profile="${trimmed#Active Profile: }"
          active_profile="$(trim_trailing "$active_profile")"
          active_desc="${profile_desc_map[$active_profile]}"
          continue
        fi
        if [[ "$trimmed" =~ ^Ports: ]]; then
          in_profiles=0
          continue
        fi
        [[ -z "$trimmed" ]] && continue
        if [[ "$trimmed" =~ ^([^:]+):[[:space:]]*(.+)$ ]]; then
          local profile="${BASH_REMATCH[1]}"
          profile="$(trim_trailing "$profile")"
          local rest="${BASH_REMATCH[2]}"
          local desc="${rest%% (*}"
          desc="$(trim_trailing "$desc")"
          profile_desc_map["$profile"]="$desc"
        fi
        continue
      fi

      if [[ "$trimmed" =~ ^Active\ Profile:\ (.+)$ ]]; then
        active_profile="${BASH_REMATCH[1]}"
        active_profile="$(trim_trailing "$active_profile")"
        active_desc="${profile_desc_map[$active_profile]}"
        continue
      fi
    done < <(pactl list cards)

    flush_card
  }

  list_card_profiles() {
    local card_id="$1"
    local in_card=0
    local in_profiles=0
    local active=""
    declare -a profiles=()

    while IFS= read -r line; do
      if [[ "$line" =~ ^Card\ #[0-9]+ ]]; then
        local cur="${line#Card #}"
        cur="${cur%% *}"
        if [[ "$cur" == "$card_id" ]]; then
          in_card=1
          in_profiles=0
          active=""
          profiles=()
          continue
        elif ((in_card)); then
          break
        fi
      fi

      ((in_card)) || continue

      local trimmed
      trimmed="$(trim_leading "$line")"

      if [[ "$trimmed" =~ ^Profiles: ]]; then
        in_profiles=1
        continue
      fi

      if ((in_profiles)); then
        if [[ "$trimmed" =~ ^Active\ Profile: ]]; then
          in_profiles=0
          active="${trimmed#Active Profile: }"
          active="$(trim_trailing "$active")"
          continue
        fi
        if [[ "$trimmed" =~ ^Ports: ]]; then
          in_profiles=0
          continue
        fi
        [[ -z "$trimmed" ]] && continue
        if [[ "$trimmed" =~ ^([^[:space:]]+):[[:space:]]+(.+)$ ]]; then
          local profile="${BASH_REMATCH[1]}"
          profile="$(trim_trailing "$profile")"
          local rest="${BASH_REMATCH[2]}"
          local desc="${rest%% (*}"
          desc="$(trim_trailing "$desc")"
          local avail="unknown"
          if [[ "$rest" =~ available:[[:space:]]*([[:alpha:]]+) ]]; then
            avail="${BASH_REMATCH[1]}"
          fi
          profiles+=("$profile"$'\t'"$desc"$'\t'"$avail")
        fi
        continue
      fi

      if [[ "$trimmed" =~ ^Active\ Profile:\ (.+)$ ]]; then
        active="${BASH_REMATCH[1]}"
        active="$(trim_trailing "$active")"
        continue
      fi
    done < <(pactl list cards)

    local entry
    for entry in "${profiles[@]}"; do
      IFS=$'\t' read -r profile desc avail <<<"$entry"
      local is_active="no"
      [[ "$profile" == "$active" ]] && is_active="yes"
      printf '%s\t%s\t%s\t%s\n' "$profile" "$desc" "$avail" "$is_active"
    done
  }

  set_card_profile() {
    local card_name="$1"
    local profile="$2"
    local desc="$3"
    [[ -z "$desc" ]] && desc="$profile"

    if pactl set-card-profile "$card_name" "$profile"; then
      notify "Profile set to ${desc}"
      refresh_pactl_defaults
      return 0
    else
      notify "Failed to set profile: ${profile}"
      return 1
    fi
  }
else
  refresh_wpctl_status() {
    if ! WPCTL_STATUS="$(wpctl status 2>/dev/null)"; then
      die "Failed to query PipeWire via 'wpctl status'. Is WirePlumber running?"
    fi
  }

  refresh_wpctl_status

  list_devices() {
    local type="$1"
    local section=""
    case "$type" in
    sink | source) ;;
    *) return 1 ;;
    esac

    while IFS= read -r line; do
      case "$line" in
      *"Sinks:"*)
        section="sink"
        continue
        ;;
      *"Sources:"*)
        section="source"
        continue
        ;;
      *"Sink Inputs:"* | *"Source Outputs:"* | *"Devices:"* | *"Clients:"*)
        section=""
        ;;
      esac

      [[ "$section" != "$type" ]] && continue

      local cleaned stripped
      stripped="$(strip_tree_chars "$line")"
      cleaned="$(trim_leading "$stripped")"
      cleaned="$(trim_trailing "$cleaned")"
      [[ -z "$cleaned" ]] && continue

      local is_default="no"
      while [[ "$cleaned" == [\*\+\!]* ]]; do
        [[ "${cleaned:0:1}" == "*" ]] && is_default="yes"
        cleaned="${cleaned:1}"
        cleaned="$(trim_leading "$cleaned")"
      done

      if [[ "$cleaned" =~ ^([0-9]+)\.[[:space:]]*(.+)$ ]]; then
        local id="${BASH_REMATCH[1]}"
        local desc="${BASH_REMATCH[2]}"
        desc="$(trim_trailing "$desc")"
        printf '%s\t%s\t%s\t%s\t%s\n' "$type" "$id" "$desc" "$is_default" "$id"
      fi
    done <<<"$WPCTL_STATUS"
  }

  wpctl_collect_node_ids() {
    local header="$1"
    local section=""
    local -a ids=()
    while IFS= read -r line; do
      case "$line" in
      *"Sink Inputs:"*)
        section="sink-inputs"
        continue
        ;;
      *"Source Outputs:"*)
        section="source-outputs"
        continue
        ;;
      *"Sinks:"* | *"Sources:"* | *"Devices:"* | *"Clients:"* | *"Media Sessions:"*)
        [[ "$section" == "$header" ]] && break
        section=""
        ;;
      esac
      [[ "$section" != "$header" ]] && continue

      local stripped cleaned
      stripped="$(strip_tree_chars "$line")"
      cleaned="$(trim_leading "$stripped")"
      cleaned="$(trim_trailing "$cleaned")"
      [[ -z "$cleaned" ]] && continue

      if [[ "$cleaned" =~ ^([0-9]+)\.[[:space:]]*(.+)$ ]]; then
        ids+=("${BASH_REMATCH[1]}")
      fi
    done <<<"$WPCTL_STATUS"

    printf '%s\n' "${ids[@]}"
  }

  move_sink_inputs() {
    local target="$1"
    refresh_wpctl_status
    mapfile -t sink_inputs < <(wpctl_collect_node_ids "sink-inputs")
    for node in "${sink_inputs[@]}"; do
      [[ -z "$node" ]] && continue
      wpctl move-node "$node" "$target" >/dev/null 2>&1 || true
    done
  }

  move_source_outputs() {
    local target="$1"
    refresh_wpctl_status
    mapfile -t source_outputs < <(wpctl_collect_node_ids "source-outputs")
    for node in "${source_outputs[@]}"; do
      [[ -z "$node" ]] && continue
      wpctl move-node "$node" "$target" >/dev/null 2>&1 || true
    done
  }

  set_default_device() {
    local type="$1"
    local name="$2"
    local desc="$3"
    [[ -z "$desc" ]] && desc="$name"

    case "$type" in
    sink)
      wpctl set-default "$name"
      move_sink_inputs "$name"
      notify "Output set to ${desc}"
      ;;
    source)
      wpctl set-default "$name"
      move_source_outputs "$name"
      notify "Input set to ${desc}"
      ;;
    esac

    refresh_wpctl_status
  }

  list_card_profiles() {
    local card_id="$1"
    if ! have pw-dump; then
      return 1
    fi
    if [[ -z "${PYTHON_BIN:-}" ]]; then
      return 1
    fi

    "$PYTHON_BIN" - "$card_id" <<'PY'
import sys, json, subprocess
card_id = sys.argv[1]
result = subprocess.run(['pw-dump', card_id], capture_output=True, text=True, check=False)
data = json.loads(result.stdout) if result.returncode == 0 and result.stdout else None
if not data:
    sys.exit(0)
info = data[0].get("info", {})
params = info.get("params", {})
enum_profiles = params.get("EnumProfile", [])
active_profiles = params.get("Profile", [])
active_name = None
if active_profiles:
    active_name = active_profiles[0].get("name")
for prof in enum_profiles:
    name = prof.get("name") or ""
    desc = prof.get("description") or name
    avail = prof.get("available", "unknown")
    if isinstance(avail, bool):
        avail = "yes" if avail else "no"
    else:
        avail = str(avail).lower()
        if avail in ("true", "1", "available", "yes"):
            avail = "yes"
        elif avail in ("false", "0", "no", "unavailable"):
            avail = "no"
    is_active = "yes" if name == active_name else "no"
    print(f"{name}\t{desc}\t{avail}\t{is_active}")
PY
  }

  get_wpctl_card_profile_summary() {
    local card_id="$1"
    local summary
    summary="$(list_card_profiles "$card_id" 2>/dev/null | awk -F'\t' '$4=="yes"{print $1"\t"$2; exit}')"
    [[ -n "$summary" ]] || return 1
    printf '%s\n' "$summary"
    return 0
  }

  list_audio_cards() {
    refresh_wpctl_status
    local section=""

    while IFS= read -r line; do
      case "$line" in
      *"Devices:"*)
        section="devices"
        continue
        ;;
      *"Sinks:"* | *"Sink endpoints:"* | *"Sources:"* | *"Source endpoints:"*)
        if [[ "$section" == "devices" ]]; then
          break
        fi
        section=""
        ;;
      esac

      [[ "$section" != "devices" ]] && continue

      local stripped cleaned
      stripped="$(strip_tree_chars "$line")"
      cleaned="$(trim_leading "$stripped")"
      cleaned="$(trim_trailing "$cleaned")"
      [[ -z "$cleaned" ]] && continue

      while [[ "$cleaned" == [\*+!]* ]]; do
        cleaned="${cleaned:1}"
        cleaned="$(trim_leading "$cleaned")"
      done

      if [[ "$cleaned" =~ ^([0-9]+)\.[[:space:]]*([^[]+)(\[[^]]*\])? ]]; then
        local id="${BASH_REMATCH[1]}"
        local desc="${BASH_REMATCH[2]}"
        desc="$(trim_trailing "$desc")"
        local summary
        local active_name=""
        local active_desc=""
        if summary="$(get_wpctl_card_profile_summary "$id" 2>/dev/null)"; then
          active_name="${summary%%$'\t'*}"
          active_desc="${summary#*$'\t'}"
          [[ "$active_desc" == "$summary" ]] && active_desc="$active_name"
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$id" "${desc:-Device $id}" "$active_name" "$active_desc"
      fi
    done <<<"$WPCTL_STATUS"
  }

  set_card_profile() {
    local card_id="$1"
    local profile="$2"
    local desc="$3"
    [[ -z "$desc" ]] && desc="$profile"

    if wpctl set-profile "$card_id" "$profile" >/dev/null 2>&1; then
      notify "Profile set to ${desc}"
      refresh_wpctl_status
      return 0
    else
      notify "Failed to set profile: ${profile}"
      return 1
    fi
  }
fi

show_device_menu() {
  local type="$1"
  local prompt=""
  local icon=""
  local noun="Output"
  local back_label="↩  Back"

  case "$type" in
  sink)
    prompt="  outputs"
    icon=""
    noun="Output"
    ;;
  source)
    prompt="  inputs"
    icon=""
    noun="Input"
    ;;
  *)
    return 0
    ;;
  esac

  if [[ "$AUDIO_BACKEND" == "wpctl" ]]; then
    refresh_wpctl_status
  else
    refresh_pactl_defaults
  fi

  declare -a entries=()
  declare -a actions=()
  declare -A desc_map=()

  # shellcheck disable=SC2034
  while IFS=$'\t' read -r dtype name desc is_default index; do
    [[ -z "${name:-}" ]] && continue
    [[ "$dtype" != "$type" ]] && continue
    desc="${desc:-$name}"

    local entry_icon="$icon"
    local escaped_desc
    local escaped_name
    local display_name
    local label

    escaped_desc="$(rofi_escape "$desc")"
    escaped_name="$(rofi_escape "$name")"
    display_name="$escaped_name"
    if [[ "$AUDIO_BACKEND" == "wpctl" ]]; then
      display_name="#${display_name}"
    fi

    label="${entry_icon}  ${escaped_desc}"
    [[ "$is_default" == "yes" ]] && label+=" <span alpha=\"70%\">[default]</span>"
    label+=" <span alpha=\"60%\">(${display_name})</span>"

    entries+=("$label")
    actions+=("${type}|${name}")
    desc_map["${type}|${name}"]="$desc"
  done < <(list_devices "$type")

  if ((${#entries[@]} == 0)); then
    notify "No ${noun,,}s found."
    return 0
  fi

  entries=("$back_label" "${entries[@]}")
  actions=("back" "${actions[@]}")
  desc_map["back"]=""

  local choice
  choice="$(printf '%s\n' "${entries[@]}" | run_rofi "$prompt")"
  [[ -z "${choice:-}" ]] && exit 0

  if [[ "$choice" == "$back_label" ]]; then
    return 0
  fi

  local selected_action=""
  for idx in "${!entries[@]}"; do
    if [[ "${entries[$idx]}" == "$choice" ]]; then
      selected_action="${actions[$idx]}"
      break
    fi
  done

  [[ -z "$selected_action" ]] && exit 0

  local selected_name desc
  IFS='|' read -r _ selected_name <<<"$selected_action"
  desc="${desc_map[$selected_action]}"

  [[ -z "${selected_name:-}" ]] && exit 0

  set_default_device "$type" "$selected_name" "$desc"
  return 2
}

show_profile_picker() {
  local card_id="$1"
  local card_name="$2"
  local card_desc="$3"
  local back_label="↩  Back"

  while true; do
    local -a entries=()
    local -a actions=()
    local -A avail_map=()
    local -A desc_map=()

    while IFS=$'\t' read -r profile desc avail is_active; do
      [[ -z "${profile:-}" ]] && continue
      desc="${desc:-$profile}"

      local escaped_desc
      escaped_desc="$(rofi_escape "$desc")"
      local label="  ${escaped_desc}"
      [[ "$is_active" == "yes" ]] && label+=" <span alpha=\"70%\">[active]</span>"
      if [[ "$avail" == "no" ]]; then
        label+=" <span alpha=\"40%\">(unavailable)</span>"
      fi

      entries+=("$label")
      actions+=("$profile")
      avail_map["$profile"]="$avail"
      desc_map["$profile"]="$desc"
    done < <(list_card_profiles "$card_id")

    if ((${#entries[@]} == 0)); then
      notify "No profiles found for ${card_desc}."
      return 0
    fi

    entries=("$back_label" "${entries[@]}")
    actions=("back" "${actions[@]}")

    local choice
    choice="$(printf '%s\n' "${entries[@]}" | run_rofi "  profiles")"
    [[ -z "${choice:-}" ]] && exit 0

    if [[ "$choice" == "$back_label" ]]; then
      return 0
    fi

    local selected_profile=""
    for idx in "${!entries[@]}"; do
      if [[ "${entries[$idx]}" == "$choice" ]]; then
        selected_profile="${actions[$idx]}"
        break
      fi
    done

    [[ -z "$selected_profile" ]] && exit 0

    if [[ "${avail_map[$selected_profile]}" == "no" ]]; then
      notify "Profile not available: ${desc_map[$selected_profile]}"
      continue
    fi

    if set_card_profile "$card_name" "$selected_profile" "${desc_map[$selected_profile]}"; then
      return 2
    fi
  done
}

show_profiles_menu() {
  local back_label="↩  Back"

  if [[ "$AUDIO_BACKEND" == "wpctl" ]]; then
    if [[ -z "${PYTHON_BIN:-}" ]]; then
      notify "Profiles menu requires python3."
      return 0
    fi
    if ! have pw-dump; then
      notify "Profiles menu requires pw-dump (PipeWire tools)."
      return 0
    fi
  fi

  while true; do
    local -a entries=()
    local -a actions=()

    while IFS=$'\t' read -r card_id card_name card_desc active_name active_desc; do
      [[ -z "${card_id:-}" ]] && continue
      local escaped_desc
      escaped_desc="$(rofi_escape "$card_desc")"
      local label="  ${escaped_desc}"

      local active_label="${active_desc:-$active_name}"
      if [[ -n "$active_label" ]]; then
        active_label="$(rofi_escape "$active_label")"
        label+=" <span alpha=\"70%\">[$active_label]</span>"
      fi
      entries+=("$label")
      actions+=("$card_id"$'\t'"$card_name"$'\t'"$card_desc")
    done < <(list_audio_cards)

    if ((${#entries[@]} == 0)); then
      notify "No audio cards found."
      return 0
    fi

    entries=("$back_label" "${entries[@]}")
    actions=("back" "${actions[@]}")

    local choice
    choice="$(printf '%s\n' "${entries[@]}" | run_rofi "  profiles")"
    [[ -z "${choice:-}" ]] && exit 0

    if [[ "$choice" == "$back_label" ]]; then
      return 0
    fi

    local selected_action=""
    for idx in "${!entries[@]}"; do
      if [[ "${entries[$idx]}" == "$choice" ]]; then
        selected_action="${actions[$idx]}"
        break
      fi
    done

    [[ -z "$selected_action" ]] && exit 0

    IFS=$'\t' read -r card_id card_name card_desc <<<"$selected_action"
    [[ -z "${card_id:-}" ]] && continue

    local rc=0
    show_profile_picker "$card_id" "$card_name" "$card_desc"
    rc=$?
    if [[ "$rc" -eq 2 ]]; then
      return 2
    fi
  done
}

main_menu() {
  local options=(
    "  Outputs"
    "  Inputs"
    "  Profiles"
  )

  while true; do
    local choice
    choice="$(printf '%s\n' "${options[@]}" | run_rofi "  audio")"
    [[ -z "${choice:-}" ]] && exit 0

    local rc=0
    case "$choice" in
    "  Outputs")
      show_device_menu sink
      rc=$?
      ;;
    "  Inputs")
      show_device_menu source
      rc=$?
      ;;
    "  Profiles")
      show_profiles_menu
      rc=$?
      ;;
    *)
      rc=0
      ;;
    esac

    if [[ "$rc" -eq 2 ]]; then
      return 0
    fi
  done
}

main_menu
