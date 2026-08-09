#!/usr/bin/env bash
set -euo pipefail

get_zoom() {
    local zoom
    zoom=$(hyprctl getoption -j cursor:zoom_factor 2>/dev/null | jq -r '.float // 1.0' 2>/dev/null || echo "1.0")
    if [[ ! "$zoom" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        zoom="1.0"
    fi
    echo "$zoom"
}

set_zoom() {
    local val="$1"
    local clamped
    clamped=$(awk -v v="$val" 'BEGIN { if (v < 1.0) v = 1.0; if (v > 5.0) v = 5.0; printf "%.2f", v }')
    hyprctl repl "hl.config({ cursor = { zoom_factor = $clamped } })" >/dev/null 2>&1 || \
    hyprctl keyword cursor:zoom_factor "$clamped" >/dev/null 2>&1 || true
}

CURRENT_ZOOM=$(get_zoom)
STEP="${2:-0.2}"

case "${1:-}" in
    reset) set_zoom 1.0 ;;
    increase)
        NEW_ZOOM=$(awk -v z="$CURRENT_ZOOM" -v s="$STEP" 'BEGIN { printf "%.2f", z + s }')
        set_zoom "$NEW_ZOOM"
        ;;
    decrease)
        NEW_ZOOM=$(awk -v z="$CURRENT_ZOOM" -v s="$STEP" 'BEGIN { printf "%.2f", z - s }')
        set_zoom "$NEW_ZOOM"
        ;;
    *) exit 1 ;;
esac