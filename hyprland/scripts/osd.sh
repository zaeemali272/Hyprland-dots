#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
DIR="${2:-}"

send_notify() {
    local val="$1" tag="$2" msg="$3"
    notify-send \
        -t 1000 \
        -h "int:value:$val" \
        -h "string:x-canonical-private-synchronous:$tag" \
        -h "string:category:$tag" \
        "$msg"
}

case "$ACTION" in
brightness)
    STEP=2
    CUR_RAW=$(brightnessctl get 2>/dev/null || echo 0)
    MAX=$(brightnessctl max 2>/dev/null || echo 100)
    (( MAX == 0 )) && MAX=100
    (( CUR = CUR_RAW * 100 / MAX ))

    case "$DIR" in
        up)   brightnessctl set "+${STEP}%" >/dev/null ;;
        down)
            if (( CUR <= 2 )); then
                brightnessctl set 0% >/dev/null
            else
                brightnessctl set "${STEP}%-" >/dev/null
            fi
            ;;
    esac

    CUR_RAW=$(brightnessctl get 2>/dev/null || echo 0)
    (( CUR = CUR_RAW * 100 / MAX ))

    if (( CUR <= 33 )); then
        icon="🔅"
    elif (( CUR <= 66 )); then
        icon="☀️"
    else
        icon="🔆"
    fi

    send_notify "$CUR" brightness "$icon  Brightness ${CUR}%"
    ;;

volume)
    STEP=3
    STATUS=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.00")
    VOL=$(awk '{print int($2 * 100)}' <<<"$STATUS")
    MUTED=$(grep -q MUTED <<<"$STATUS" && echo 1 || echo 0)

    case "$DIR" in
        up)
            if (( MUTED )); then
                wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null || true
            fi
            wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${STEP}%+" >/dev/null
            ;;
        down)
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}%-" >/dev/null
            ;;
        mute)
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null
            ;;
    esac

    STATUS=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.00")
    VOL=$(awk '{print int($2 * 100)}' <<<"$STATUS")

    if grep -q MUTED <<<"$STATUS"; then
        send_notify 0 volume "  Muted"
    else
        if (( VOL == 0 )); then
            icon=""
        elif (( VOL <= 30 )); then
            icon=""
        else
            icon=""
        fi
        send_notify "$VOL" volume "$icon  Volume ${VOL}%"
    fi
    ;;
esac