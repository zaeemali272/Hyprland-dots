#!/usr/bin/env bash
set -euo pipefail

# Graceful termination first (SIGTERM), fallback to SIGKILL
pkill -15 quickshell aww 2>/dev/null || true
sleep 0.3
pkill -9 quickshell aww 2>/dev/null || true

# Restart Quickshell in daemon mode & restore wallpaper service
nohup quickshell -d >/dev/null 2>&1 &
nohup aww >/dev/null 2>&1 &

# Restart user-space services cleanly
systemctl --user restart pipewire wireplumber bluetooth.service 2>/dev/null || true

# Reload Hyprland configuration and state
hyprctl reload >/dev/null
notify-send -i system-restart -a "Hyprland" "Desktop services reloaded"