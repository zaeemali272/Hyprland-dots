#!/usr/bin/env bash

# Icons (pick any Nerd Font / Material icons you like)
ICON_ON="󰯈"   # connected
ICON_OFF="󰯉"  # disconnected

get_status() {
    if warp-cli status | grep -q "Connected"; then
        echo "$ICON_ON"
    else
        echo "$ICON_OFF"
    fi
}

toggle() {
    if warp-cli status | grep -q "Connected"; then
        warp-cli disconnect >/dev/null 2>&1
    else
        warp-cli connect >/dev/null 2>&1
    fi
}

case "$1" in
    --toggle) toggle ;;
    *) get_status ;;
esac
