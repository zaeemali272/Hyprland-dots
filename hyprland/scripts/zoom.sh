#!/usr/bin/env bash
get_zoom() {
    hyprctl getoption -j cursor:zoom_factor | jq '.float'
}

set_zoom() {
    local val="$1"
    awk -v v="$val" 'BEGIN {
        if (v < 1.0) v = 1.0;
        if (v > 3.0) v = 3.0;
        system("hyprctl keyword cursor:zoom_factor " v);
    }'
}

case "$1" in
    reset) set_zoom 1.0 ;;
    increase)
        [[ -z "$2" ]] && exit 1
        set_zoom "$(awk "BEGIN { print $(get_zoom) + $2 }")"
        ;;
    decrease)
        [[ -z "$2" ]] && exit 1
        set_zoom "$(awk "BEGIN { print $(get_zoom) - $2 }")"
        ;;
    *) exit 1 ;;
esac