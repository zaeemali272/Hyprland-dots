#!/bin/bash

# Laptop battery info
BATTERY=$(upower -e | grep battery_BAT | head -n 1)

if [[ -n "$BATTERY" ]]; then
    LP_PERCENT=$(upower -i "$BATTERY" | awk '/percentage:/ {print $2}' | tr -d '%')
    LP_STATE=$(upower -i "$BATTERY" | awk '/state:/ {print $2}')
    
    if [ "$LP_PERCENT" -ge 90 ]; then LP_ICON="󰁹";
    elif [ "$LP_PERCENT" -ge 70 ]; then LP_ICON="󰂀";
    elif [ "$LP_PERCENT" -ge 50 ]; then LP_ICON="󰁿";
    elif [ "$LP_PERCENT" -ge 30 ]; then LP_ICON="󰁾";
    elif [ "$LP_PERCENT" -ge 10 ]; then LP_ICON="󰁽";
    else LP_ICON="󰁼"; fi

    if [[ "$LP_STATE" == "charging" || "$LP_STATE" == "fully-charged" || "$LP_STATE" == "pending-charge" ]]; then
        LP_DISPLAY="󰂄 $LP_PERCENT%"
    else
        LP_DISPLAY="$LP_ICON $LP_PERCENT%"
    fi
else
    LP_DISPLAY=""
fi

# Bluetooth battery info
DEVICE_MAC="41:42:E8:67:6B:66"
DEVICE_PATH=$(echo "$DEVICE_MAC" | sed 's/:/_/g')
UPOWER_PATH="/org/freedesktop/UPower/devices/headset_dev_${DEVICE_PATH}"

# Check if BT device is connected before showing battery
BT_CONNECTED=$(bluetoothctl info "$DEVICE_MAC" 2>/dev/null | grep -c "Connected: yes")

if [ "$BT_CONNECTED" -eq 1 ] && upower -i "$UPOWER_PATH" &>/dev/null; then
    BT_PERCENT=$(upower -i "$UPOWER_PATH" | awk '/percentage:/ {print $2}' | tr -d '%')
    BT_STATE=$(upower -i "$UPOWER_PATH" | awk '/state:/ {print $2}')

    if [ "$BT_PERCENT" -ge 90 ]; then BT_ICON="󰥉";
    elif [ "$BT_PERCENT" -ge 70 ]; then BT_ICON="󰥉";
    elif [ "$BT_PERCENT" -ge 50 ]; then BT_ICON="󰥇 ";
    elif [ "$BT_PERCENT" -ge 30 ]; then BT_ICON="󰥆 ";
    elif [ "$BT_PERCENT" -ge 10 ]; then BT_ICON="󰥅 ";
    else BT_ICON="󰥄"; fi

    if [[ "$BT_STATE" == "charging" || "$BT_STATE" == "fully-charged" || "$BT_STATE" == "pending-charge" ]]; then
        BT_DISPLAY="󰂯 $BT_PERCENT%"
    else
        BT_DISPLAY="$BT_ICON $BT_PERCENT%"
    fi
else
    BT_DISPLAY=""
fi

# Compose output
if [[ -n "$BT_DISPLAY" && -n "$LP_DISPLAY" ]]; then
    echo "$BT_DISPLAY | $LP_DISPLAY"
elif [[ -n "$BT_DISPLAY" ]]; then
    echo "$BT_DISPLAY"
elif [[ -n "$LP_DISPLAY" ]]; then
    echo "$LP_DISPLAY"
else
    echo ""
fi

