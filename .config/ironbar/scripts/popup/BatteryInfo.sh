#!/bin/bash

# Automatically detect battery and AC adapter paths
BAT_PATH=$(ls /sys/class/power_supply/ | grep -E 'BAT' | head -n1)
AC_PATH=$(ls /sys/class/power_supply/ | grep -E 'AC|ADP|ACAD' | head -n1)

echo "==============================="
echo "BATTERY INFO ::"
echo "==============================="

grep -E "CAPACITY=|STATUS=|CYCLE_COUNT=|VOLTAGE_NOW=|HEALTH=" "/sys/class/power_supply/$BAT_PATH/uevent" \
    | while IFS='=' read -r key value; do
        key=${key#POWER_SUPPLY_}
        if [[ "$key" == "VOLTAGE_NOW" ]]; then
            # convert from µV to V
            value=$(echo "scale=2; $value/1000000" | bc)
            echo "$key=$value V"
        else
            echo "$key=$value"
        fi
      done

echo "==============================="
echo "ADAPTER INFO ::"
echo "==============================="

grep "ONLINE=" "/sys/class/power_supply/$AC_PATH/uevent" | sed 's/POWER_SUPPLY_//g'
