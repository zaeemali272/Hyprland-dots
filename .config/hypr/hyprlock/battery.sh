#!/bin/bash

BAT_PATH=$(ls /sys/class/power_supply/ | grep -E 'BAT' | head -n1)
AC_PATH=$(ls /sys/class/power_supply/ | grep -E 'AC|ADP|ACAD' | head -n1)/online

capacity=$(<"$BAT_PATH/capacity")
ac_online=$(<"$AC_PATH")

if [ "$ac_online" -eq 1 ]; then
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

