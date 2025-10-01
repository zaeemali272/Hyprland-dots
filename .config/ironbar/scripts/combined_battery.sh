#!/bin/bash
# Ironbar universal battery widget (Laptop + Bluetooth)
# Portable, fail-safe, non-blocking (sysfs + UPower + BT fallback)

BT_CACHE="/tmp/bt_battery.cache"

# ================== Laptop Battery ==================
LP=""

# Detect battery and AC paths safely
BAT_PATH=$(find /sys/class/power_supply/ -maxdepth 1 -type d -name 'BAT*' | head -n1 | xargs -r basename)
AC_PATH=$(find /sys/class/power_supply/ -maxdepth 1 -type d -regex '.*/\(AC\|ADP\|ACAD\)*' | head -n1 | xargs -r basename)

if [[ -n "$BAT_PATH" && -d "/sys/class/power_supply/$BAT_PATH" ]]; then
    PERC=$(<"/sys/class/power_supply/$BAT_PATH/capacity")
    STATE=$(<"/sys/class/power_supply/$BAT_PATH/status")

    AC_CONNECTED=0
    if [[ -n "$AC_PATH" && -f "/sys/class/power_supply/$AC_PATH/online" ]]; then
        AC_CONNECTED=$(<"/sys/class/power_supply/$AC_PATH/online")
    fi

    # Laptop battery icons logic
    if (( AC_CONNECTED == 1 )) && [[ "$STATE" =~ [Nn]ot[[:space:]]charging|[Ii]dle|[Uu]nknown ]]; then
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
    # UPower fallback safely
    if command -v upower >/dev/null 2>&1; then
        UDEV=$(upower -e 2>/dev/null | grep -i BAT | head -n1 || echo "")
        if [[ -n "$UDEV" ]]; then
            PERC=$(upower -i "$UDEV" 2>/dev/null | awk '/percentage/ {gsub("%",""); print $2}' || echo 0)
            STATE=$(upower -i "$UDEV" 2>/dev/null | awk '/state/ {print $2}' || echo "unknown")

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
fi

# ================== Bluetooth Battery ==================
BT=""
if command -v bluetoothctl >/dev/null 2>&1; then
    DEVICE_MAC=$(timeout 1s bluetoothctl devices Connected 2>/dev/null | awk '{print $2}' | head -n1 || echo "")
    if [[ -n "$DEVICE_MAC" ]]; then
        CONNECTED=$(timeout 1s bluetoothctl info "$DEVICE_MAC" 2>/dev/null | grep -c "Connected: yes" || echo 0)
        if ((CONNECTED == 1)); then
            RAW=$(timeout 1s bluetoothctl info "$DEVICE_MAC" 2>/dev/null | awk '/Battery Percentage/ {print $3}' || echo "")
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
fi

# ================== Compose final output ==================
OUTPUT=""
[[ -n "$BT" ]] && OUTPUT+="$BT"
[[ -n "$LP" ]] && OUTPUT+="${OUTPUT:+ | }$LP"
[[ -z "$OUTPUT" ]] && OUTPUT="⚡ N/A"

echo "$OUTPUT"

