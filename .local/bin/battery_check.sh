#!/bin/bash

# Automatically detect battery capacity and status paths
BAT_DIR=$(ls /sys/class/power_supply/ | grep -E 'BAT' | head -n1)
BAT_PATH="/sys/class/power_supply/$BAT_DIR/capacity"
STATUS_PATH="/sys/class/power_supply/$BAT_DIR/status"

PERCENT=$(<"$BAT_PATH")
STATUS=$(<"$STATUS_PATH")

STATE_FILE="/tmp/.battery_warn_state"
LAST_STATE=$(<"$STATE_FILE" 2>/dev/null || echo "none")

notify_battery() {
    notify-send -u critical "Battery Warning" "$1"
}

if [[ "$STATUS" != "Charging" ]]; then
    if (( PERCENT <= 5 )) && [[ "$LAST_STATE" != "5" ]]; then
        notify_battery "Battery critically low ($PERCENT%). Plug in now!"
        echo "5" > "$STATE_FILE"
    elif (( PERCENT <= 20 )) && [[ "$LAST_STATE" != "20" ]]; then
        notify_battery "Battery low ($PERCENT%). Consider plugging in."
        echo "20" > "$STATE_FILE"
    elif (( PERCENT > 20 )) && [[ "$LAST_STATE" != "none" ]]; then
        echo "none" > "$STATE_FILE"
    fi
fi
