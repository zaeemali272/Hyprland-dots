#!/usr/bin/env bash
# ~/.config/ironbar/scripts/netspeed_toggle.sh

MODE_FILE="/tmp/.netspeed_mode"

if [[ ! -f "$MODE_FILE" ]]; then
    echo "down" > "$MODE_FILE"
fi

MODE=$(<"$MODE_FILE")

if [[ "$MODE" == "down" ]]; then
    echo "up" > "$MODE_FILE"
else
    echo "down" > "$MODE_FILE"
fi
