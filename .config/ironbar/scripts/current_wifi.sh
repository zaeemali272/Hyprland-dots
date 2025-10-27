#!/usr/bin/env bash
# ~/.config/ironbar/scripts/current_network.sh
# Shows "Ethernet", connected SSID, or "Offline"

# --- Detect Ethernet ---
ETH_IFACE=$(ip -o link show | awk -F': ' '/enp|eth|eno|ens/ {print $2; exit}')
if [[ -n "$ETH_IFACE" ]]; then
    if ip link show "$ETH_IFACE" | grep -q "state UP" && ip addr show "$ETH_IFACE" | grep -q "inet "; then
        echo "Ethernet"
        exit 0
    fi
fi

# --- Detect Wi-Fi (IWD/iwctl) ---
WIFI_IFACE=$(iwctl device list 2>/dev/null | awk '/station/ {print $2; exit}')
if [[ -n "$WIFI_IFACE" ]]; then
    SSID=$(iwctl station "$WIFI_IFACE" show 2>/dev/null | awk -F 'network' '/Connected network/ {print $2}' | xargs)
    if [[ -n "$SSID" ]]; then
        echo "$SSID"
        exit 0
    fi
fi

# --- Fallback ---
echo "Not Connected"

