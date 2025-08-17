#!/bin/bash
if xset q | grep -q "Caps Lock:   on"; then
    echo "Caps Lock is ON"
else
    echo ""
fi
