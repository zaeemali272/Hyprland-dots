#!/bin/bash

IFACE="wlp0s20f3"
PREV_FILE="/tmp/.netspeed_rx_prev"

RX_NOW=$(< /sys/class/net/$IFACE/statistics/rx_bytes)

if [[ -f "$PREV_FILE" ]]; then
    RX_PREV=$(< "$PREV_FILE")
    BYTES=$((RX_NOW - RX_PREV))
else
    BYTES=0
fi

echo "$RX_NOW" > "$PREV_FILE"

# Convert to MB/s and pad to fixed width
MBPS=$(bc <<< "scale=2; $BYTES/1048576")
SPEED=$(printf "%4.2f" "$MBPS") # always 6 chars wide, 2 decimal places

echo "󰁅 ${SPEED} MB/s"

