#!/usr/bin/env bash
# ~/.config/ironbar/scripts/netspeed.sh
# Shows netspeed (download/upload) depending on toggle

MODE_FILE="/tmp/.netspeed_mode"
[[ -f "$MODE_FILE" ]] || echo "down" > "$MODE_FILE"
MODE=$(<"$MODE_FILE")

if [[ "$MODE" == "down" ]]; then
    STAT_FILE="/sys/class/net/$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1);exit}}')/statistics/rx_bytes"
    PREV_FILE="/tmp/.netspeed_rx_prev"
    ICON="󰁆"   # download icon
else
    STAT_FILE="/sys/class/net/$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1);exit}}')/statistics/tx_bytes"
    PREV_FILE="/tmp/.netspeed_tx_prev"
    ICON="󰁞"   # upload icon
fi

[[ -f "$STAT_FILE" ]] || exit 0

# Load previous
PREV=0
[[ -f "$PREV_FILE" ]] && PREV=$(<"$PREV_FILE")

NOW=$(<"$STAT_FILE")
DELTA=$((NOW - PREV))
echo "$NOW" > "$PREV_FILE"

# Convert to Mb/s
MBPS=$(bc <<< "scale=2; ($DELTA*8)/1000000")
SPEED=$(printf "%02d" "$(echo "$MBPS" | cut -d. -f1 | cut -c1-2)")

echo "$ICON ${SPEED} Mb/s"

