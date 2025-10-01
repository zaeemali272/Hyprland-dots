#!/bin/bash
# Ironbar universal battery widget (Laptop + Bluetooth)
# Uses your original icons and logic, but adds portability (sysfs + upower fallback)

BT_CACHE="/tmp/bt_battery.cache"

# ================== Laptop Battery ==================
LP=""
BAT_PATH=$(find /sys/class/power_supply/ -maxdepth 1 -type d -name 'BAT*' | head -n1 | xargs -r basename)
AC_PATH=$(find /sys/class/power_supply/ -maxdepth 1 -type d -regex '.*/\(AC\|ADP\|ACAD\)*' | head -n1 | xargs -r basename)

if [[ -n "$BAT_PATH" && -d "/sys/class/power_supply/$BAT_PATH" ]]; then
    PERC=$(<"/sys/class/power_supply/$BAT_PATH/capacity")
    STATE=$(<"/sys/class/power_supply/$BAT_PATH/status")

    AC_CONNECTED=0
    if [[ -n "$AC_PATH" && -f "/sys/class/power_supply/$AC_PATH/online" ]]; then
        AC_CONNECTED=$(<"/sys/class/power_supply/$AC_PATH/online")
    fi

    # Show plug icon if AC is connected and battery NOT charging
    if (( AC_CONNECTED == 1 )) && [[ "$STATE" =~ [Nn]ot\ charging|[Ii]dle|[Uu]nknown ]]; then
        LP=" $PERC%"
    else
        if ((PERC >= 90)); then ICON="󰁹"
        elif ((PERC >= 70)); then ICON="󰂀"
        elif ((PERC >= 50)); then ICON="󰁿"
        elif ((PERC >= 30)); then ICON="󰁾"
        elif ((PERC >= 10)); then ICON="󰁽"
        else ICON="󰁼"; fi

        if [[ "$STATE" =~ ([Cc]harging|[Ff]ull) ]]; then
            LP="󰂄 $PERC%"
        else
            LP="$ICON $PERC%"
        fi
    fi
else
    # ================== UPower fallback ==================
    UDEV=$(upower -e | grep -i BAT | head -n1)
    if [[ -n "$UDEV" ]]; then
        PERC=$(upower -i "$UDEV" | awk '/percentage/ {gsub("%",""); print $2}')
        STATE=$(upower -i "$UDEV" | awk '/state/ {print $2}')

        if [[ "$STATE" == "charging" || "$STATE" == "fully-charged" ]]; then
            LP="󰂄 $PERC%"
        elif [[ "$STATE" == "pending-charge" || "$STATE" == "idle" ]]; then
            LP=" $PERC%"
        else
            if ((PERC >= 90)); then ICON="󰁹"
            elif ((PERC >= 70)); then ICON="󰂀"
            elif ((PERC >= 50)); then ICON="󰁿"
            elif ((PERC >= 30)); then ICON="󰁾"
            elif ((PERC >= 10)); then ICON="󰁽"
            else ICON="󰁼"; fi
            LP="$ICON $PERC%"
        fi
    fi
fi

# ================== Bluetooth Battery ==================
BT=""
DEVICE_MAC=$(bluetoothctl devices Connected | awk '{print $2}' | head -n1)
if [[ -n "$DEVICE_MAC" ]]; then
    CONNECTED=$(bluetoothctl info "$DEVICE_MAC" 2>/dev/null | grep -c "Connected: yes")
    if ((CONNECTED == 1)); then
        RAW=$(bluetoothctl info "$DEVICE_MAC" 2>/dev/null | awk '/Battery Percentage/ {print $3}')
        if [[ "$RAW" =~ 0x[0-9a-fA-F]+ ]]; then
            PERC=$((16#${RAW:2}))
        else
            PERC="${RAW%%%}" # strip % if present
        fi
        if [[ "$PERC" =~ ^[0-9]+$ ]]; then
            if ((PERC >= 90)); then ICON="󰥉"
            elif ((PERC >= 70)); then ICON="󰥉"
            elif ((PERC >= 50)); then ICON="󰥇"
            elif ((PERC >= 30)); then ICON="󰥆"
            elif ((PERC >= 10)); then ICON="󰥅"
            else ICON="󰥄"; fi
            BT="$ICON $PERC%"
            echo "$BT" > "$BT_CACHE"
        fi
    else
        echo "" > "$BT_CACHE"
    fi
else
    echo "" > "$BT_CACHE"
fi

# ================== Compose output ==================
if [[ -n "$BT" && -n "$LP" ]]; then
    echo "$BT | $LP"
elif [[ -n "$BT" ]]; then
    echo "$BT"
else
    echo "$LP"
fi

