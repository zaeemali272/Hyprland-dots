#!/bin/bash

# Get volume + mute state
status=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)

# Extract float and convert to integer percent
volume=$(echo "$status" | awk '{print int($2 * 100)}')

if echo "$status" | grep -q MUTED; then
    icon=" "   # Font Awesome: volume-off
    text="Muted"
else
    if [ "$volume" -eq 0 ]; then
        icon="  "   # fa-volume-off
    elif [ "$volume" -le 30 ]; then
        icon="  "   # fa-volume-down
    else
        icon="   "   # fa-volume-up
    fi
    text="Volume: ${volume}%"
fi

notify-send -t 1000 \
    -h int:value:$volume \
    -h string:x-canonical-private-synchronous:volume \
    "$icon $text"

