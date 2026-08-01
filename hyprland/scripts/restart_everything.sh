#!/usr/bin/env bash

# Kill and restart Quickshell daemon & wallpapers
pkill -9 quickshell 2>/dev/null || true
pkill -9 aww 2>/dev/null || true

sleep 0.5

# Restart Quickshell in daemon mode & restore wallpaper service
quickshell -d &
aww & # Adjust this if your aww daemon command has specific flags

# Restart user-space services cleanly
systemctl --user restart pipewire wireplumber bluetooth.service 2>/dev/null || true

# Reload Hyprland configuration and state
hyprctl reload