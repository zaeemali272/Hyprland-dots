#!/bin/bash

echo "==============================="
echo "BATTERY INFO ::"
echo "==============================="

grep -E "CAPACITY=|STATUS=|CYCLE_COUNT=|VOLTAGE_NOW=|HEALTH=" /sys/class/power_supply/BAT0/uevent \
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

grep "ONLINE=" /sys/class/power_supply/ADP0/uevent | sed 's/POWER_SUPPLY_//g'

