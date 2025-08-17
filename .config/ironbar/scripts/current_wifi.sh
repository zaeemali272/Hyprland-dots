#!/usr/bin/env bash
# ~/.config/ironbar/scripts/current_wifi.sh

IFACE=$(ip link show | awk -F: '/w/ {print $2; exit}' | xargs)
SSID=$(iw dev "$IFACE" link | awk -F': ' '/SSID/ {print $2}')
[[ -z "$SSID" ]] && SSID="Not connected"
echo "$SSID"

