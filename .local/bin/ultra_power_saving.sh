#!/usr/bin/env bash
# ultra_power_saving.sh
# Strips system down to bare essentials + Hyprland tweaks + Ironbar switch
# Root-level operations are handled via /usr/local/bin/upsm-root.sh with NOPASSWD

STATE_FILE="/tmp/ultra_power_saving.state"
IRONBAR="/usr/bin/ironbar"
IRONBAR_CONFIG="$HOME/.config/ironbar"
ROOT_HELPER="/usr/local/bin/upsm-root.sh"

COMPOSITOR="picom"
HYPRLAND_ENABLED=true

enable_mode() {
    echo ">>> Enabling Ultra Power Saving..."

    # Root-level tweaks (services, journald, VM, USB, timers)
    sudo "$ROOT_HELPER" enable

    # Save and reduce brightness
    current_brightness=$(brightnessctl g)
    max_brightness=$(brightnessctl m)
    echo "$current_brightness" > /tmp/upsm_brightness
    percent=$(( current_brightness * 100 / max_brightness ))
    if [ "$percent" -gt 25 ]; then
        brightnessctl set 25% >/dev/null
    fi

    # Suspend compositor
    if pgrep -x "$COMPOSITOR" >/dev/null; then
        pkill -STOP "$COMPOSITOR"
        echo "$COMPOSITOR" > /tmp/upsm_compositor_suspended
    fi

    # Hyprland: save current effects + disable for power saving
    if [ "$HYPRLAND_ENABLED" = true ]; then
        hyprctl getoption animations:enabled | awk '{print $2}' > /tmp/upsm_hypr_animations
        hyprctl getoption decoration:blur:enabled | awk '{print $2}' > /tmp/upsm_hypr_blur
        hyprctl getoption decoration:shadow:enabled | awk '{print $2}' > /tmp/upsm_hypr_shadow
        hyprctl getoption decoration:rounding | awk '{print $3}' > /tmp/upsm_hypr_rounding
        hyprctl getoption decoration:active_opacity | awk '{print $2}' > /tmp/upsm_hypr_active
        hyprctl getoption decoration:inactive_opacity | awk '{print $2}' > /tmp/upsm_hypr_inactive
        hyprctl getoption decoration:dim_inactive | awk '{print $2}' > /tmp/upsm_hypr_dim

        hyprctl keyword animations:enabled 0
        hyprctl keyword decoration:blur:enabled 0
        hyprctl keyword decoration:shadow:enabled 0
        hyprctl keyword decoration:rounding 0
        hyprctl keyword decoration:active_opacity 1.0
        hyprctl keyword decoration:inactive_opacity 1.0
        hyprctl keyword decoration:dim_inactive false
    fi

    # Switch Ironbar to minimal layout
    if [ -f "$IRONBAR_CONFIG/minimal.corn" ]; then
        cp "$IRONBAR_CONFIG/minimal.corn" "$IRONBAR_CONFIG/config.corn"
        pkill ironbar && "$IRONBAR" &
    fi

    echo "on" > "$STATE_FILE"
    echo ">>> Ultra Power Saving Mode ENABLED"
}

disable_mode() {
    echo ">>> Disabling Ultra Power Saving..."

    # Root-level restore
    sudo "$ROOT_HELPER" disable

    # Restore brightness
    if [ -f /tmp/upsm_brightness ]; then
        brightnessctl set "$(cat /tmp/upsm_brightness)" >/dev/null
        rm /tmp/upsm_brightness
    fi

    # Resume compositor
    if [ -f /tmp/upsm_compositor_suspended ]; then
        COMPOSITOR=$(< /tmp/upsm_compositor_suspended)
        pkill -CONT "$COMPOSITOR"
        rm /tmp/upsm_compositor_suspended
    fi

    # Restore Hyprland effects
    if [ "$HYPRLAND_ENABLED" = true ]; then
        [ -f /tmp/upsm_hypr_animations ] && hyprctl keyword animations:enabled "$(cat /tmp/upsm_hypr_animations)" && rm /tmp/upsm_hypr_animations
        [ -f /tmp/upsm_hypr_blur ] && hyprctl keyword decoration:blur:enabled "$(cat /tmp/upsm_hypr_blur)" && rm /tmp/upsm_hypr_blur
        [ -f /tmp/upsm_hypr_shadow ] && hyprctl keyword decoration:shadow:enabled "$(cat /tmp/upsm_hypr_shadow)" && rm /tmp/upsm_hypr_shadow
        [ -f /tmp/upsm_hypr_rounding ] && hyprctl keyword decoration:rounding "$(cat /tmp/upsm_hypr_rounding)" && rm /tmp/upsm_hypr_rounding
        [ -f /tmp/upsm_hypr_active ] && hyprctl keyword decoration:active_opacity "$(cat /tmp/upsm_hypr_active)" && rm /tmp/upsm_hypr_active
        [ -f /tmp/upsm_hypr_inactive ] && hyprctl keyword decoration:inactive_opacity "$(cat /tmp/upsm_hypr_inactive)" && rm /tmp/upsm_hypr_inactive
        [ -f /tmp/upsm_hypr_dim ] && hyprctl keyword decoration:dim_inactive "$(cat /tmp/upsm_hypr_dim)" && rm /tmp/upsm_hypr_dim
        hyprctl reload
    fi

    # Switch Ironbar back to default layout
    if [ -f "$IRONBAR_CONFIG/default.corn" ]; then
        cp "$IRONBAR_CONFIG/default.corn" "$IRONBAR_CONFIG/config.corn"
        pkill ironbar && "$IRONBAR" &
    fi

    rm -f "$STATE_FILE"
    echo ">>> Ultra Power Saving Mode DISABLED"
}

# Toggle mode
if [ -f "$STATE_FILE" ]; then
    disable_mode
else
    enable_mode
fi

