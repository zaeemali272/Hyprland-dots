#!/bin/bash
# /usr/local/bin/bluetooth-autofix.sh
# Reconnect to the last used or first paired Bluetooth device

set -euo pipefail

restart_bt() {
    echo "Restarting bluetooth.service..."
    systemctl restart bluetooth.service
    sleep 2
    bluetoothctl power on || true
}

# Restart Bluetooth stack first
restart_bt

# Find last connected device (check history of paired devices)
DEVICE=$(bluetoothctl devices | awk '{print $2}' | while read -r mac; do
    if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
        echo "$mac"
        break
    fi
done)

# Fallback: first paired device
if [ -z "$DEVICE" ]; then
  DEVICE=$(bluetoothctl devices | awk '{print $2}' | head -n1)
  [ -n "$DEVICE" ] && echo "Fallback: $DEVICE"
fi

[ -z "$DEVICE" ] && { echo "No paired devices found."; exit 1; }

# Try connecting up to 3 times
for i in {1..3}; do
    echo "Attempt $i to connect to $DEVICE..."
    if bluetoothctl connect "$DEVICE" | grep -q "Connection successful"; then
        echo "✅ Connected to $DEVICE."
        exit 0
    fi
    echo "❌ Failed, retrying..."
    restart_bt
    sleep 2
done

echo "❌ Failed to connect after 3 attempts."
exit 1

