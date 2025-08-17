#!/bin/bash

# Max characters for display
MAX_LENGTH=

# Get the player status
status=$(playerctl status 2>/dev/null)
song=$(playerctl metadata --format "{{ artist }} - {{ title }}" 2>/dev/null)

# Choose icon based on status
case "$status" in
    Playing) icon="" ;;   # Play icon
    Paused)  icon="" ;;   # Pause icon
    *)       icon="" ;;   # Stop / Nothing
esac

# Truncate song if too long
if [ -n "$song" ] && [ ${#song} -gt $MAX_LENGTH ]; then
    song="${song:0:$MAX_LENGTH}…"
fi

# Output
if [ -z "$song" ]; then
    echo "$icon  Nothing playing"
else
    echo "$icon  $song"
fi

