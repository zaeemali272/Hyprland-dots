#!/bin/bash
# Ironbar battery widget (one-shot)

BT_CACHE="/tmp/bt_battery.cache"

# Automatically detect laptop battery
BAT_PATH=$(ls /sys/class/power_supply/ | grep -E 'BAT' | head -n1)

# Automatically detect first connected Bluetooth device
DEVICE_MAC=$(bluetoothctl devices Connected | awk '{print $2}' | head -n1)

# Laptop battery
LP=""
if [[ -d "/sys/class/power_supply/$BAT_PATH" ]]; then
    PERC=$(<"/sys/class/power_supply/$BAT_PATH/capacity")
    STATE=$(<"/sys/class/power_supply/$BAT_PATH/status")
    if ((PERC >= 90)); then ICON="󰁹"
    elif ((PERC >= 70)); then ICON="󰂀"
    elif ((PERC >= 50)); then ICON="󰁿"
    elif ((PERC >= 30)); then ICON="󰁾"
    elif ((PERC >= 10)); then ICON="󰁽"
    else ICON="󰁼"; fi
    [[ "$STATE" =~ [Cc]harging|[Ff]ull ]] && LP="󰂄 $PERC%" || LP="$ICON $PERC%"
fi

# Bluetooth battery
BT=""
if [[ -n "$DEVICE_MAC" ]]; then
    CONNECTED=$(bluetoothctl info "$DEVICE_MAC" 2>/dev/null | grep -c "Connected: yes")
    if ((CONNECTED == 1)); then
        HEX=$(bluetoothctl info "$DEVICE_MAC" 2>/dev/null | awk '/Battery Percentage/ {print $3}')
        if [[ "$HEX" =~ 0x[0-9a-fA-F]+ ]]; then
            PERC=$((16#${HEX:2}))
        else
            PERC="$HEX"
        fi
        if ((PERC >= 90)); then ICON="󰥉"
        elif ((PERC >= 70)); then ICON="󰥉"
        elif ((PERC >= 50)); then ICON="󰥇"
        elif ((PERC >= 30)); then ICON="󰥆"
        elif ((PERC >= 10)); then ICON="󰥅"
        else ICON="󰥄"; fi
        BT="$ICON $PERC%"
        echo "$BT" > "$BT_CACHE"
    else
        echo "" > "$BT_CACHE"
    fi
else
    echo "" > "$BT_CACHE"
fi

# Compose output
if [[ -n "$BT" && -n "$LP" ]]; then
    echo "$BT | $LP"
elif [[ -n "$BT" ]]; then
    echo "$BT"
else
    echo "$LP"
fi

