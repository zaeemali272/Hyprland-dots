#!/bin/bash

LOCKFILE="/tmp/bluetooth-autofix.lock"
LOGFILE="/var/log/bluetooth-autofix.log"

# Automatically detect the first paired device
DEVICE=$(bluetoothctl paired-devices | awk '{print $2}' | head -n1)

# Exit if no device found
if [[ -z "$DEVICE" ]]; then
    echo "[$(date)] No paired Bluetooth devices found. Exiting." >> "$LOGFILE"
    exit 1
fi

# Prevent duplicate runs
if [ -e "$LOCKFILE" ]; then
  echo "[$(date)] Script already running. Exiting." >> "$LOGFILE"
  exit 0
fi
touch "$LOCKFILE"

echo "[$(date)] Starting bluetooth autofix for device $DEVICE..." >> "$LOGFILE"

# Restart bluetooth service
systemctl restart bluetooth.service
sleep 3

# Ensure power is on
bluetoothctl power on >> "$LOGFILE" 2>&1

# Try connecting up to 3 times
for i in {1..3}; do
    echo "[$(date)] Attempt $i to connect..." >> "$LOGFILE"
    if bluetoothctl connect "$DEVICE" >> "$LOGFILE" 2>&1; then
        echo "[$(date)] Connected successfully." >> "$LOGFILE"
        rm -f "$LOCKFILE"
        exit 0
    fi
    sleep 3
done

echo "[$(date)] Failed to connect after 3 attempts." >> "$LOGFILE"
rm -f "$LOCKFILE"
exit 1
