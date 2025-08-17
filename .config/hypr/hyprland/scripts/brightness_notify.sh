#!/bin/bash

BRIGHTNESS=$(brightnessctl get)
MAX=$(brightnessctl max)
PERCENT=$(( BRIGHTNESS * 100 / MAX ))

# Pick icon like Android
if [ "$PERCENT" -le 33 ]; then
    icon="🔅"
elif [ "$PERCENT" -le 66 ]; then
    icon="☀️"
else
    icon="🔆"
fi

notify-send -t 1000 \
    -h int:value:$PERCENT \
    -h string:x-canonical-private-synchronous:brightness \
    "$icon Brightness: ${PERCENT}%"

