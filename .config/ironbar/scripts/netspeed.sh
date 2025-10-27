#!/usr/bin/env bash
# ~/.config/ironbar/scripts/netspeed.sh
# Shows accurate netspeed (download/upload) with proper timing

MODE_FILE="/tmp/.netspeed_mode"
[[ -f "$MODE_FILE" ]] || echo "down" > "$MODE_FILE"
MODE=$(<"$MODE_FILE")

# Get active interface
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1);exit}}')
[[ -n "$IFACE" ]] || exit 0

if [[ "$MODE" == "down" ]]; then
    STAT_FILE="/sys/class/net/$IFACE/statistics/rx_bytes"
    PREV_FILE="/tmp/.netspeed_rx_prev"
    ICON=""
else
    STAT_FILE="/sys/class/net/$IFACE/statistics/tx_bytes"
    PREV_FILE="/tmp/.netspeed_tx_prev"
    ICON=""
fi

[[ -r "$STAT_FILE" ]] || exit 0

NOW_BYTES=$(<"$STAT_FILE")
NOW_TIME=$(date +%s.%N)

PREV_BYTES=0
PREV_TIME=$NOW_TIME
if [[ -f "$PREV_FILE" ]]; then
    read -r PREV_BYTES PREV_TIME < "$PREV_FILE"
fi

# Save current stats
echo "$NOW_BYTES $NOW_TIME" > "$PREV_FILE"

# Handle rollover
if (( NOW_BYTES < PREV_BYTES )); then
    DELTA_BYTES=$(( (NOW_BYTES + (1<<63)*2) - PREV_BYTES ))
else
    DELTA_BYTES=$(( NOW_BYTES - PREV_BYTES ))
fi

# Time delta in seconds (float)
DELTA_TIME=$(awk "BEGIN {print $NOW_TIME - $PREV_TIME}")

# Avoid division by zero
if (( $(awk "BEGIN {print ($DELTA_TIME <= 0)}") )); then
    echo "$ICON 00 Mb/s"
    exit 0
fi

# Bits per second → Mbps
MBPS=$(awk "BEGIN {printf \"%.0f\", ($DELTA_BYTES * 8) / (1000000 * $DELTA_TIME)}")

printf "%s %02d Mb/s\n" "$ICON" "$MBPS"

