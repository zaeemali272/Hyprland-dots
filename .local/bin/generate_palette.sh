#!/usr/bin/env bash
# Usage: generate_palette.sh /path/to/wallpaper.jpg

WALLPAPER="$1"
PALETTE_FILE="$HOME/.cache/wallpaper_palette"

if [[ -f "$WALLPAPER" ]]; then
    wallust "$WALLPAPER" > "$PALETTE_FILE"
    echo "Palette saved to $PALETTE_FILE"
else
    echo "Wallpaper not found: $WALLPAPER"
    exit 1
fi

