#!/usr/bin/env bash
set -euo pipefail

# Graceful termination first (SIGTERM), fallback to SIGKILL
pkill -15 -f "quickshell|aww" 2>/dev/null || true
sleep 0.3
pkill -9 -f "quickshell|aww" 2>/dev/null || true

# Restart Quickshell in daemon mode & restore wallpaper service if available
if command -v quickshell >/dev/null 2>&1; then
    nohup quickshell -d >/dev/null 2>&1 &
fi
if command -v aww >/dev/null 2>&1; then
    nohup aww >/dev/null 2>&1 &
fi

# Restart user-space audio services cleanly if systemctl exists
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user restart pipewire wireplumber xdg-desktop-portal-hyprland xdg-desktop-portal 2>/dev/null || true
fi

# Reload Hyprland configuration and state
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send -i system-restart -a "Hyprland" "Desktop services reloaded" 2>/dev/null || true
fi