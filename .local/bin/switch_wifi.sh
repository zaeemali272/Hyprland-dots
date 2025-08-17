#!/usr/bin/env bash
# switch_wifi.sh for iwd (no sudo password needed)
# $1 = SSID, $2 = PSK

SSID="$1"
PSK="$2"

# Auto-detect WiFi interface
IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')
[[ -z "$IFACE" ]] && echo "No WiFi interface found!" && exit 1

# Connect using iwd via D-Bus (requires iwd.service running)
iwctl station "$IFACE" connect "$SSID" <<< "$PSK"

# Optional: wait a few seconds to ensure connection
sleep 2

# Check status
iwctl station "$IFACE" show

