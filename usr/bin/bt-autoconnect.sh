#!/bin/bash

# Wait a few seconds for the Bluetooth service to start
sleep 5

# Get the last connected device (most recent)
DEVICE=$(bluetoothctl devices | awk '{print $2}' | tail -n1)

# Exit if no device found
[[ -z "$DEVICE" ]] && exit 0

# Connect in the background
/usr/bin/bluetoothctl connect "$DEVICE" &
wait
