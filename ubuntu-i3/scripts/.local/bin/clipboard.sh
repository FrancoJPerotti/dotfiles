#!/bin/bash

rofi -no-lazy-grab -show-icons false -modi 'clipboard:greenclip print' \
    -show clipboard -run-command '{cmd}' \
    -kb-cancel "Escape,Super+c" \
    -theme-str 'element { padding: 10px; } element-icon { size: 0px; }'
