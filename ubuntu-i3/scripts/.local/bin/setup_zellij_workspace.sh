#!/bin/bash

# Setup Zellij workspace with project tabs and tool agent tabs

SESSION_NAME="workspace"
TOOLS_DIR="$HOME/tools"
ABRAM_DIR="$HOME/repos/abram_rules"
LAYOUT_FILE="/tmp/zellij-workspace-layout.kdl"

# Check if session already exists (check for active sessions, not exited ones)
if zellij list-sessions --no-formatting 2>/dev/null | grep "^$SESSION_NAME" | grep -qv "EXITED"; then
    echo "Session '$SESSION_NAME' already exists. Attaching..."
    exec zellij attach "$SESSION_NAME"
fi

# Clean up any dead sessions with the same name
if zellij list-sessions --no-formatting 2>/dev/null | grep -q "^$SESSION_NAME"; then
    echo "Cleaning up dead session '$SESSION_NAME'..."
    zellij delete-session "$SESSION_NAME" 2>/dev/null
fi

echo "Creating workspace layout..."

# Generate layout file dynamically
cat > "$LAYOUT_FILE" << 'LAYOUT_START'
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        children
        pane size=2 borderless=true {
            plugin location="zellij:status-bar"
        }
    }

LAYOUT_START

# Add Project tabs
for i in {1..3}; do
    cat >> "$LAYOUT_FILE" << EOF
    tab name="Project_$i" {
        pane
    }
EOF
done

# Add ABRAM Rules Agent tab
if [ -d "$ABRAM_DIR" ]; then
    cat >> "$LAYOUT_FILE" << EOF
    tab name="ABRAM Rules Agent" {
        pane cwd="$ABRAM_DIR"
    }
EOF
else
    cat >> "$LAYOUT_FILE" << 'EOF'
    tab name="ABRAM Rules Agent" {
        pane
    }
EOF
fi

# Find all tool directories and add tabs for them
if [ -d "$TOOLS_DIR" ]; then
    for category in "$TOOLS_DIR"/*; do
        if [ -d "$category" ]; then
            for tool in "$category"/*; do
                if [ -d "$tool" ]; then
                    tool_name=$(basename "$tool" | tr '[:lower:]' '[:upper:]' | sed 's/_/ /g')
                    tab_name="${tool_name} Agent"
                    cat >> "$LAYOUT_FILE" << EOF
    tab name="$tab_name" {
        pane cwd="$tool"
    }
EOF
                fi
            done
        fi
    done
fi

# Close layout
echo "}" >> "$LAYOUT_FILE"

echo "Launching zellij workspace in new terminal..."
LAYOUT_FILE="$LAYOUT_FILE" SESSION_NAME="$SESSION_NAME" exec kitty zsh -c "
    zellij --new-session-with-layout \"\$LAYOUT_FILE\" --session \"\$SESSION_NAME\" || { echo 'Zellij failed!'; read; }
"
