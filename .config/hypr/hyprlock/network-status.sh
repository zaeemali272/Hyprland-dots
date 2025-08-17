#!/bin/bash

# Detect Ethernet
eth_iface=$(ip -o link show | awk -F': ' '/state UP/ && $2 ~ /^en/{print $2; exit}')

# Detect Wi-Fi
wifi_iface=$(ip -o link show | awk -F': ' '/state UP/ && $2 ~ /^wl/{print $2; exit}')

if [ -n "$wifi_iface" ]; then
    # Get SSID directly from iw (works with iwd too)
    ssid=$(iw dev "$wifi_iface" link | awk -F': ' '/SSID/ {print $2}')
    if [ -n "$ssid" ]; then
        echo "   $ssid"
    else
        echo "󰤯   Connecting..."
    fi
elif [ -n "$eth_iface" ]; then
    echo "󰈀   Ethernet"
else
    echo "   Offline"
fi

