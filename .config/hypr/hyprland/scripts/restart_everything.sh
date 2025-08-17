#!/bin/bash

# Kill & restart Ironbar
pkill ironbar
sleep 0.5
ironbar &

# Kill & restart Mako
pkill mako
sleep 0.5
mako &

# Restart Bluetooth service
systemctl --user restart bluetooth.service 2>/dev/null || \
sudo systemctl restart bluetooth.service
