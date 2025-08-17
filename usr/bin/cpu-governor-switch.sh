#!/bin/bash

# File: /usr/local/bin/cpu-governor-switch.sh

# Auto-detect AC adapter
AC_STATUS_FILE=$(ls /sys/class/power_supply/ | grep -E 'AC|ADP|ACAD' | head -n1)
AC_STATUS_PATH="/sys/class/power_supply/$AC_STATUS_FILE/online"

if [[ ! -f "$AC_STATUS_PATH" ]]; then
    echo "AC adapter not found."
    exit 1
fi

AC_ONLINE=$(<"$AC_STATUS_PATH")

if [[ "$AC_ONLINE" -eq 1 ]]; then
    echo "AC connected: Switching to performance mode."
    cpupower frequency-set -g performance
    echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
else
    echo "On battery: Switching to powersave mode."
    cpupower frequency-set -g powersave
    echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null
fi
