#!/usr/bin/env bash
# Toggle Waydroid full UI with pin + slide + auto-hide (polling-based)

set -euo pipefail

WAYDROID_CLASS="Waydroid"
SHOW_X=9
HIDE_X=-500
Y_POS=45
WIDTH=481
HEIGHT=1025
STEP=40      # slide step in px
DELAY=0.01   # frame delay for sliding
POLL_DELAY=0.5   # polling interval for auto-hide (.5 second)

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
require hyprctl
require jq

get_win_id() {
  hyprctl clients -j | jq -r ".[] | select(.class==\"$WAYDROID_CLASS\") | .address" | head -n1
}

get_x() {
  local win="$1"
  hyprctl clients -j | jq -r ".[] | select(.address==\"$win\") | .at[0]"
}

slide_window() {
  local from="$1" to="$2" win="$3"
  if [[ -z "$from" || -z "$to" ]]; then return; fi
  if (( from < to )); then
    for ((x=from; x<=to; x+=STEP)); do
      hyprctl dispatch movewindowpixel exact "$x" "$Y_POS",address:"$win" >/dev/null
      sleep "$DELAY"
    done
  else
    for ((x=from; x>=to; x-=STEP)); do
      hyprctl dispatch movewindowpixel exact "$x" "$Y_POS",address:"$win" >/dev/null
      sleep "$DELAY"
    done
  fi
  hyprctl dispatch movewindowpixel exact "$to" "$Y_POS",address:"$win" >/dev/null
}

pin_show_resize() {
  local win="$1"
  # Floating + visible on all workspaces
  hyprctl dispatch setfloating address:"$win" >/dev/null
  hyprctl dispatch stick address:"$win" >/dev/null
  hyprctl dispatch resizewindowpixel exact "$WIDTH" "$HEIGHT",address:"$win" >/dev/null
  hyprctl dispatch bringactivetotop address:"$win" >/dev/null
}

auto_hide_on_unfocus() {
  local win="$1"
  while true; do
    sleep "$POLL_DELAY"
    # get active window
    ACTIVE=$(hyprctl activewindow -j | jq -r '.address')
    if [[ "$ACTIVE" != "$win" && "$ACTIVE" != "0x0000000000000000" ]]; then
      slide_window "$(get_x "$win")" "$HIDE_X" "$win"
      break
    fi
  done
}

# ---------------- main toggle ----------------
WIN_ID=$(get_win_id || true)

if [[ -n "${WIN_ID:-}" ]]; then
  CUR_X=$(get_x "$WIN_ID" || echo "$SHOW_X")
  if [[ "$CUR_X" == "$SHOW_X" ]]; then
    # visible -> slide out
    slide_window "$CUR_X" "$HIDE_X" "$WIN_ID"
  else
    # hidden -> slide in
    pin_show_resize "$WIN_ID"
    slide_window "$CUR_X" "$SHOW_X" "$WIN_ID"
    auto_hide_on_unfocus "$WIN_ID" &
  fi
else
  # spawn UI and place it
  waydroid show-full-ui &
  for i in {1..20}; do
    sleep 0.1
    WIN_ID=$(get_win_id || true)
    [[ -n "${WIN_ID:-}" ]] && break
  done
  [[ -z "${WIN_ID:-}" ]] && { echo "Waydroid window not found"; exit 1; }

  pin_show_resize "$WIN_ID"
  hyprctl dispatch movewindowpixel exact "$HIDE_X" "$Y_POS",address:"$WIN_ID" >/dev/null
  slide_window "$HIDE_X" "$SHOW_X" "$WIN_ID"
  auto_hide_on_unfocus "$WIN_ID" &
fi

