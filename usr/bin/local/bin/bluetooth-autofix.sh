#!/bin/bash

LOCKFILE="/tmp/bluetooth-autofix.lock"
LOGFILE="/var/log/bluetooth-autofix.log"
DEVICE="41:42:E8:67:6B:66"  # your MAC

# Prevent duplicate runs
if [ -e "$LOCKFILE" ]; then
  echo "[$(date)] Script already running. Exiting." >> "$LOGFILE"
  exit 0
fi
touch "$LOCKFILE"

echo "[$(date)] Starting bluetooth autofix..." >> "$LOGFILE"

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

