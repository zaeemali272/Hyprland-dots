#!/usr/bin/env bash
# One-shot netspeed_down.sh for Ironbar

PREV_FILE="/tmp/.netspeed_rx_prev"

# Automatically detect the active network interface (excluding lo)
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1);exit}}}')

[[ -z "$IFACE" || ! -d /sys/class/net/$IFACE ]] && exit 0

# Read previous RX
RX_PREV=0
[[ -f "$PREV_FILE" ]] && RX_PREV=$(<"$PREV_FILE")

# Current RX
RX_NOW=$(< /sys/class/net/$IFACE/statistics/rx_bytes)

# Delta calculation
BYTES=$((RX_NOW - RX_PREV))
echo "$RX_NOW" > "$PREV_FILE"

# Convert to MB/s, 2 decimals
MBPS=$(bc <<< "scale=2; $BYTES/1048576")
SPEED=$(printf "%4.2f" "$MBPS")

echo "󰁅 ${SPEED} MB/s"

