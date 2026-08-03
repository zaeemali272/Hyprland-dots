#!/usr/bin/env bash
set -euo pipefail

DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"

MODE="${1:-region}"

if hyprshot -m "$MODE" -o "$DIR" --silent; then
    LATEST_FILE=$(ls -t "$DIR" 2>/dev/null | head -n1 || true)
    if [ -n "$LATEST_FILE" ] && [ -f "$DIR/$LATEST_FILE" ]; then
        echo -n "$DIR/$LATEST_FILE" | wl-copy 2>/dev/null || true
        notify-send \
            -i camera-photo \
            -a "Screenshot" \
            -h string:x-canonical-private-synchronous:screenshot \
            "Screenshot Saved" \
            "$LATEST_FILE"
    fi
else
    notify-send \
        -i camera-photo \
        -a "Screenshot" \
        -h string:x-canonical-private-synchronous:screenshot \
        "Screenshot Cancelled" ""
fi