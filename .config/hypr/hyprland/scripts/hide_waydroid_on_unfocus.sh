#!/usr/bin/env bash
# Auto-hide Waydroid when it loses focus

WAYDROID_CLASS="Waydroid"
HIDE_X=-2000   # Offscreen
Y_POS=45
SLIDE_SPEED=10 # pixels per step
SLIDE_DELAY=0.005

slide_out() {
    WIN_ID="$1"
    CUR_X=$(hyprctl clients -j | jq -r ".[] | select(.address==\"$WIN_ID\") | .at[0]")

    while [ "$CUR_X" -gt "$HIDE_X" ]; do
        CUR_X=$((CUR_X - SLIDE_SPEED))
        hyprctl dispatch movewindowpixel exact "$CUR_X" "$Y_POS",address:"$WIN_ID"
        sleep "$SLIDE_DELAY"
    done
}

hyprctl -j events | jq -r 'select(.event=="activewindow") | .data' | while read -r ADDR; do
    # If focus is NOT Waydroid, slide it out
    WAYDROID_ID=$(hyprctl clients -j | jq -r ".[] | select(.class==\"$WAYDROID_CLASS\") | .address")
    if [ -n "$WAYDROID_ID" ] && [ "$ADDR" != "$WAYDROID_ID" ]; then
        slide_out "$WAYDROID_ID"
    fi
done

