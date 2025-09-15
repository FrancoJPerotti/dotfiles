#!/bin/bash
#
# Manages Vivaldi keyboard shortcuts by extracting them to or applying them from a JSON file.
# This script is path-agnostic and requires all file paths to be provided as arguments.
#
# USAGE:
#   ./manage_vivaldi_shortcuts.sh <command> <arguments...>
#

# --- SCRIPT LOGIC ---

# Function to display detailed usage instructions
show_usage() {
    echo "Vivaldi Shortcut Manager (Path-Agnostic)"
    echo "------------------------------------------"
    echo "This script requires the 'jq' utility to be installed."
    echo
    echo "Usage: $0 <command> <arguments...>"
    echo
    echo "Commands:"
    echo "  -g, --get    <source_prefs_file> <destination_shortcuts_file>"
    echo "               Extracts shortcuts from a Vivaldi 'Preferences' file and saves them."
    echo
    echo "  -a, --apply  <source_shortcuts_file> <destination_prefs_file>"
    echo "               Applies saved shortcuts to a Vivaldi 'Preferences' file."
    echo
    echo "  -h, --help   Display this help message."
    echo
    echo "Example (Get):"
    echo "  $0 --get ~/.config/vivaldi/Default/Preferences ~/dotfiles/vivaldi/shortcuts.json"
    echo
    echo "Example (Apply):"
    echo "  $0 --apply ~/dotfiles/vivaldi/shortcuts.json ~/.config/vivaldi/Default/Preferences"
}

# Function to extract and save the shortcuts
# $1: Path to the source Vivaldi Preferences file
# $2: Path to save the destination shortcuts.json file
get_shortcuts() {
    local source_file="$1"
    local dest_file="$2"

    echo "-> Extracting shortcuts..."
    echo "   Source: '$source_file'"
    echo "   Destination: '$dest_file'"

    if [ ! -f "$source_file" ]; then
        echo "Error: Source 'Preferences' file not found at '$source_file'"
        exit 1
    fi

    # Ensure the destination directory exists before writing
    mkdir -p "$(dirname "$dest_file")"

    # Use jq to extract the '.vivaldi.actions' object
    jq '.vivaldi.actions' "$source_file" > "$dest_file"

    if [ $? -eq 0 ]; then
        echo "Success! Shortcuts saved."
    else
        echo "Error: Failed to extract shortcuts. Is the source file a valid Vivaldi Preferences file?"
        exit 1
    fi
}

# Function to apply the saved shortcuts
# $1: Path to the source shortcuts.json file
# $2: Path to the destination Vivaldi Preferences file
apply_shortcuts() {
    local source_file="$1"
    local dest_file="$2"

    echo "-> Applying shortcuts..."
    echo "   Source: '$source_file'"
    echo "   Destination: '$dest_file'"

    if pgrep -x "vivaldi-bin" > /dev/null; then
        echo "Error: Vivaldi is running. Please close it completely before applying settings."
        exit 1
    fi
    if [ ! -f "$source_file" ]; then
        echo "Error: Source shortcuts file not found at '$source_file'."
        exit 1
    fi
    if [ ! -f "$dest_file" ]; then
        echo "Error: Destination 'Preferences' file not found at '$dest_file'."
        exit 1
    fi

    read -p "This will overwrite the shortcuts in '$dest_file'. Are you sure? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi

    local backup_file="${dest_file}.bak.$(date +%Y%m%d_%H%M%S)"
    echo "Creating a backup at '$backup_file'"
    cp "$dest_file" "$backup_file"

    # Use jq to merge the shortcuts into the destination file
    jq --argjson shortcuts "$(cat "$source_file")" '.vivaldi.actions = $shortcuts' "$backup_file" > "$dest_file"

    if [ $? -eq 0 ]; then
        echo "Success! Shortcuts have been restored."
    else
        echo "Error: Failed to apply shortcuts. Your original settings are safe in '$backup_file'."
        exit 1
    fi
}

# --- MAIN SCRIPT ---

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed, which is required. Please install it to continue."
    exit 1
fi

# If no arguments, show usage
if [ "$#" -eq 0 ]; then
    show_usage
    exit 1
fi

# Main command dispatcher
COMMAND=$1

case "$COMMAND" in
    -g|--get)
        if [ "$#" -ne 3 ]; then
            echo "Error: The '--get' command requires exactly two arguments: a source file and a destination file."
            echo
            show_usage
            exit 1
        fi
        get_shortcuts "$2" "$3"
        ;;
    -a|--apply)
        if [ "$#" -ne 3 ]; then
            echo "Error: The '--apply' command requires exactly two arguments: a source file and a destination file."
            echo
            show_usage
            exit 1
        fi
        apply_shortcuts "$2" "$3"
        ;;
    -h|--help)
        show_usage
        ;;
    *)
        echo "Error: Invalid command '$COMMAND'."
        echo
        show_usage
        exit 1
        ;;
esac
