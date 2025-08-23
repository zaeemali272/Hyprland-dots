#!/bin/bash

max_len=45
statefile="/tmp/skull_frame_index"

# Skull frames for animation
frames=( "💀" "☠️" "💀" "☠️" )

# Initialize statefile if missing
[[ ! -f $statefile ]] && echo 0 > "$statefile"

index=$(<"$statefile")
index=$(( (index + 1) % ${#frames[@]} ))
echo $index > "$statefile"

# Check default player first
status=$(playerctl status 2>/dev/null)
player=""

if [[ "$status" == "Paused" || -z "$status" ]]; then
    # Look for another player that is Playing
    for p in $(playerctl -l 2>/dev/null); do
        p_status=$(playerctl -p "$p" status 2>/dev/null)
        if [[ "$p_status" == "Playing" ]]; then
            status="Playing"
            player="$p"
            break
        fi
    done
fi

# If still no player chosen, fallback to default
[[ -z "$player" ]] && player=$(playerctl -l 2>/dev/null | head -n1)

# Icon logic
case "$status" in
  Playing) icon="  ";;   # play
  Paused)  icon="  ";;   # pause
  Stopped|"") icon="${frames[$index]}";; # skull animation
  *) icon="${frames[$index]}";;
esac

if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
    title=$(playerctl -p "$player" metadata title 2>/dev/null)
    artist=$(playerctl -p "$player" metadata artist 2>/dev/null)

    # Clean up titles for browsers
    if [[ "$player" =~ firefox|zen ]]; then
        title=$(echo "$title" | sed -E 's/^[^-]+ - //')
    else
        title=$(echo "$title" | sed -E 's/ - YouTube$//; s/ – Spotify$//; s/ \| Netflix$//')
    fi

    if [[ -n "$title" && -n "$artist" ]]; then
        now_playing="$title — $artist"
    elif [[ -n "$title" ]]; then
        now_playing="$title"
    else
        now_playing="Now Playing"
    fi

    # Truncate if too long
    (( ${#now_playing} > max_len )) && now_playing="${now_playing:0:$((max_len - 1))}…"

    echo "$icon$now_playing"
else
    echo "$icon"
fi

