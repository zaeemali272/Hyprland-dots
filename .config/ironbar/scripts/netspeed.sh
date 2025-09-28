#!/usr/bin/env bash
# ~/.config/ironbar/scripts/netspeed.sh
# Shows netspeed (download/upload) depending on toggle

MODE_FILE="/tmp/.netspeed_mode"
[[ -f "$MODE_FILE" ]] || echo "down" > "$MODE_FILE"
MODE=$(<"$MODE_FILE")

IFACE=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1);exit}}')

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

NOW=$(<"$STAT_FILE")
PREV=0
[[ -f "$PREV_FILE" ]] && PREV=$(<"$PREV_FILE")
echo "$NOW" > "$PREV_FILE"

# Handle rollover
if (( NOW < PREV )); then
    DELTA=$(( (NOW + (1<<63)*2) - PREV )) # 64-bit rollover safe
else
    DELTA=$(( NOW - PREV ))
fi

# Bytes → bits per second → Mbps
MBPS=$(( DELTA * 8 / 1000000 ))

# Keep it 2-digit padded like your original
printf "%s %02d Mb/s\n" "$ICON" "$MBPS"

