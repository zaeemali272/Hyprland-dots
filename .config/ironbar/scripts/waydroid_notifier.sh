#!/usr/bin/env bash
# waydroid_notifs.sh
# Show number of pending Waydroid/KDE Connect notifications for Ironbar

DEVICE_ID="4c23289d0caf4e06a642f604c568ea1c"
STATE_FILE="/tmp/waydroid_notify_count"

# Initialize count file
[ -f "$STATE_FILE" ] || echo 0 > "$STATE_FILE"

print_count() {
    COUNT=$(<"$STATE_FILE")
    if [ "$COUNT" -eq 0 ]; then
        echo "󰀲 "  # plain Android icon
    else
        echo "󰀲  $COUNT"  # icon + number
    fi
}

# Reset on click (Ironbar can exec this with an arg)
if [ "$1" = "reset" ]; then
    echo 0 > "$STATE_FILE"
    print_count
    exit 0
fi

# Reset when Waydroid is launched (hook toggle_waydroid.sh to call this)
if [ "$1" = "waydroid-opened" ]; then
    echo 0 > "$STATE_FILE"
    print_count
    exit 0
fi

# Default = just print the current state
print_count

