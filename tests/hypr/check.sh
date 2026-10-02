#!/usr/bin/env bash
# Syntax and behavioral checks; no running Hyprland session is needed.
set -euo pipefail
task_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
task_config_dir=${1:-"$task_root/hyde/hypr/.config/hypr"}
for task_file in "$task_config_dir/hyprland.lua" "$task_config_dir"/lua/*.lua "$task_root"/tests/hypr/*.lua; do
    luac -p "$task_file"
done
lua "$task_root/tests/hypr/run.lua" "$task_config_dir"
