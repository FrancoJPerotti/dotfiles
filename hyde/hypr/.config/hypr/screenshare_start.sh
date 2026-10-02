#!/bin/sh
set -eu

# Keep D-Bus activated portal backends on the same Wayland session as Hyprland.
dbus-update-activation-environment --systemd \
    DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
systemctl --user import-environment \
    DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE

# Restart the managed services instead of launching duplicate portal processes.
systemctl --user restart \
    xdg-desktop-portal-termfilechooser.service \
    xdg-desktop-portal-hyprland.service \
    xdg-desktop-portal.service
