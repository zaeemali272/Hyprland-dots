#!/usr/bin/env bash
ACTION="$1"
DIR="$2"

send_notify() {
    notify-send \
        -t 1000 \
        -h "int:value:$1" \
        -h "string:x-canonical-private-synchronous:$2" \
        -h "string:category:$2" \
        "$3"
}

case "$ACTION" in
brightness)
    STEP=2
    CUR_RAW=$(brightnessctl get 2>/dev/null || echo 0)
    MAX=$(brightnessctl max 2>/dev/null || echo 100)
    CUR=$(( CUR_RAW * 100 / MAX ))

    case "$DIR" in
        up)
            brightnessctl set "+${STEP}%" >/dev/null
            ;;
        down)
            if (( CUR <= 2 )); then
                brightnessctl set 0% >/dev/null
            else
                brightnessctl set "${STEP}%-" >/dev/null
            fi
            ;;
    esac

    CUR_RAW=$(brightnessctl get 2>/dev/null || echo 0)
    CUR=$(( CUR_RAW * 100 / MAX ))

    icon=$([[ $CUR -le 33 ]] && echo "🔅" || [[ $CUR -le 66 ]] && echo "☀️" || echo "🔆")
    send_notify "$CUR" brightness "$icon  Brightness ${CUR}%"
    ;;

volume)
    STEP=3
    STATUS=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.00 [MUTED]")
    VOL=$(awk '{print int($2 * 100)}' <<<"$STATUS")
    MUTED=$(grep -q MUTED <<<"$STATUS" && echo 1 || echo 0)

    case "$DIR" in
        up)
            if (( MUTED )); then
                wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
            fi
            wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${STEP}%+" >/dev/null
            ;;
        down)
            wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}%-" >/dev/null
            ;;
        mute)
            wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
            ;;
    esac

    STATUS=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.00 [MUTED]")
    VOL=$(awk '{print int($2 * 100)}' <<<"$STATUS")

    if grep -q MUTED <<<"$STATUS"; then
        icon=""
        text="Muted"
        VOL=0
    else
        icon=$([[ $VOL -eq 0 ]] && echo "  " || [[ $VOL -le 30 ]] && echo "  " || echo "  ")
        text="Volume ${VOL}%"
    fi

    send_notify "$VOL" volume "$icon  $text"
    ;;
esac