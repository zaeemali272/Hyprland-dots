#!/usr/bin/env bash

if warp-cli status | grep -q "Connected"; then
    echo "Connected"
else
    echo "Disconnected"
fi
