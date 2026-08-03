#!/usr/bin/env bash
STATE_FILE="/tmp/recording-state"

getdate() {
    date '+%Y-%m-%d_%H-%M-%S'
}

getmicinput() {
    if command -v pactl >/dev/null 2>&1; then
        pactl get-default-source 2>/dev/null || \
        pactl list sources short 2>/dev/null | awk '/input/ {print $2}' | head -n1
    elif command -v wpctl >/dev/null 2>&1; then
        wpctl inspect @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk -F'"' '/node.name/ {print $2}'
    fi
}

getsystemsound() {
    if command -v pactl >/dev/null 2>&1; then
        DEFAULT_SINK=$(pactl get-default-sink 2>/dev/null)
        if [ -n "$DEFAULT_SINK" ]; then
            echo "${DEFAULT_SINK}.monitor"
        else
            pactl list sources short 2>/dev/null | awk '/monitor/ {print $2}' | head -n1
        fi
    elif command -v wpctl >/dev/null 2>&1; then
        SINK=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F'"' '/node.name/ {print $2}')
        if [ -n "$SINK" ]; then
            echo "${SINK}.monitor"
        fi
    fi
}

getactivemonitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null
}

VIDEO_DIR="$HOME/Videos/Recordings"
mkdir -p "$VIDEO_DIR"

if pidof wl-screenrec gpu-screen-recorder > /dev/null 2>&1; then
    pkill -SIGINT -x wl-screenrec 2>/dev/null || true
    pkill -SIGINT -x gpu-screen-recorder 2>/dev/null || true
    sleep 0.6

    FILE_PATH=$(cat "$STATE_FILE" 2>/dev/null || true)
    rm -f "$STATE_FILE"

    if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
        echo -n "$FILE_PATH" | wl-copy
        notify-send \
            -i screenshooter \
            -a Recorder \
            "Recording stopped & copied to clipboard" \
            "$(basename "$FILE_PATH")"
    fi
    exit 0
fi

rm -f "$STATE_FILE"
FILE="recording_$(getdate).mp4"
FULL_PATH="$VIDEO_DIR/$FILE"
echo "$FULL_PATH" > "$STATE_FILE"

notify-send -i screenshooter -a Recorder -h string:x-canonical-private-synchronous:record "Recording started" "$FILE"

MONITOR=$(getactivemonitor)
MONITOR_ARG=()
if [ -n "$MONITOR" ]; then
    MONITOR_ARG=(-o "$MONITOR")
fi

case "$1" in
    --fullscreen-all)
        MIC=$(getmicinput)
        if [ -n "$MIC" ]; then
            nohup wl-screenrec "${MONITOR_ARG[@]}" --audio --audio-device "$MIC" -f "$FULL_PATH" >/dev/null 2>&1 &
        else
            nohup wl-screenrec "${MONITOR_ARG[@]}" --audio -f "$FULL_PATH" >/dev/null 2>&1 &
        fi
        ;;
    --fullscreen-sound)
        SOUND=$(getsystemsound)
        if [ -n "$SOUND" ]; then
            nohup wl-screenrec "${MONITOR_ARG[@]}" --audio --audio-device "$SOUND" -f "$FULL_PATH" >/dev/null 2>&1 &
        else
            nohup wl-screenrec "${MONITOR_ARG[@]}" --audio -f "$FULL_PATH" >/dev/null 2>&1 &
        fi
        ;;
    --fullscreen)
        nohup wl-screenrec "${MONITOR_ARG[@]}" -f "$FULL_PATH" >/dev/null 2>&1 &
        ;;
    --region|*)
        region=$(slurp) || {
            notify-send -a Recorder "Recording cancelled"
            rm -f "$STATE_FILE"
            exit 0
        }
        nohup wl-screenrec -g "$region" -f "$FULL_PATH" >/dev/null 2>&1 &
        ;;
esac
disown