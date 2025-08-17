#!/bin/bash

# Find the active (playing) player
player=$(playerctl -l | while read -r p; do
    status=$(playerctl -p "$p" status 2>/dev/null)
    if [ "$status" = "Playing" ]; then
        echo "$p"
        break
    fi
done)

# If no active player found, fallback to the first available
[ -z "$player" ] && player=$(playerctl -l | head -n1)

case "$player" in
  firefox)
    exec firefox &
    ;;
  spotify)
    exec spotify &
    ;;
  YoutubeMusic)
    exec youtube-music &
    ;;
  vlc)
    exec vlc &
    ;;
  mpv)
    exec mpv &
    ;;
  *)
    notify-send "No known app for player: $player"
    ;;
esac

