#!/bin/bash

# Automatically detect battery and AC adapter paths
BAT_PATH=$(ls /sys/class/power_supply/ | grep -E 'BAT' | head -n1)
AC_PATH=$(ls /sys/class/power_supply/ | grep -E 'AC|ADP|ACAD' | head -n1)

echo "==============================="
echo "BATTERY INFO ::"
echo "==============================="
grep -E "CAPACITY=|STATUS=|CYCLE_COUNT=|VOLTAGE_NOW=|CURRENT_NOW=|CHARGE_FULL=|CHARGE_FULL_DESIGN=|HEALTH=" "/sys/class/power_supply/$BAT_PATH/uevent" | sed 's/POWER_SUPPLY_//g'

echo "==============================="
echo "ADAPTER INFO ::"
echo "==============================="
grep -E "ONLINE=" "/sys/class/power_supply/$AC_PATH/uevent" | sed 's/POWER_SUPPLY_//g'

echo
read -n 1 -s -r -p "Press any key to close..."
