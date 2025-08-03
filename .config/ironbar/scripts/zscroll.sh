#!/bin/bash

# Maximum length of characters to display
max_len=40

# Check if anything is playing
status=$(playerctl status 2>/dev/null)

if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
    title=$(playerctl metadata title 2>/dev/null)
    artist=$(playerctl metadata artist 2>/dev/null)

    if [[ -n "$title" && -n "$artist" ]]; then
        now_playing="$title — $artist"
    elif [[ -n "$title" ]]; then
        now_playing="$title"
    else
        now_playing="Now Playing"
    fi

    # Truncate if longer than max_len
    if [[ ${#now_playing} -gt $max_len ]]; then
        echo "${now_playing:0:$((max_len - 1))}…"
    else
        echo "$now_playing"
    fi
else
    echo ""
fi

