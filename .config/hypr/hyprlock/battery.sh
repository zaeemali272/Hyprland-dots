#!/bin/bash

BAT_PATH=$(ls /sys/class/power_supply/ | grep -E 'BAT' | head -n1)
AC_PATH=$(ls /sys/class/power_supply/ | grep -E 'AC|ADP|ACAD' | head -n1)

capacity=$(<"/sys/class/power_supply/$BAT_PATH/capacity")
status=$(<"/sys/class/power_supply/$BAT_PATH/status")
ac_online=$(<"/sys/class/power_supply/$AC_PATH/online")

if [ "$ac_online" -eq 1 ] || [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
    icon=""  # Plugged in
else
    if [ "$capacity" -lt 20 ]; then
        icon=""
    elif [ "$capacity" -lt 40 ]; then
        icon=""
    elif [ "$capacity" -lt 60 ]; then
        icon=""
    elif [ "$capacity" -lt 80 ]; then
        icon=""
    else
        icon=""
    fi
fi

echo "$icon $capacity%"

