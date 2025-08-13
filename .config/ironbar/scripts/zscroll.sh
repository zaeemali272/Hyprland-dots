#!/bin/bash

max_len=40
statefile="/tmp/skull_frame_index"

# Skull frames for animation (can be Nerd Font icons or emojis)
frames=( "💀" "☠️" "💀" "☠️" )

# Initialize statefile if missing
if [[ ! -f $statefile ]]; then
  echo 0 > "$statefile"
fi

index=$(cat "$statefile")
index=$(( (index + 1) % ${#frames[@]} ))
echo $index > "$statefile"

status=$(playerctl status 2>/dev/null)

icon=""

case "$status" in
  Playing) icon="  ";;   # play icon
  Paused)  icon="  ";;   # pause icon
  Stopped) icon="${frames[$index]}";;  # animated skull cycle
  *)       icon="${frames[$index]}";;  # fallback skull animation
esac

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
        now_playing="${now_playing:0:$((max_len - 1))}…"
    fi

    echo "$icon$now_playing"
else
    # Show just the animated skull icon when stopped/no music
    echo "$icon"
fi

