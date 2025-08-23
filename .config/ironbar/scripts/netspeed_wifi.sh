#!/usr/bin/env bash
# Ironbar WiFi manager: JSON-based, iwd, no sudo password prompt
# Requires: jq, zenity, expect

SAVE_FILE="$HOME/.config/ironbar/wifi_saved.json"
mkdir -p "$(dirname "$SAVE_FILE")"
[[ ! -f "$SAVE_FILE" ]] && echo "{}" > "$SAVE_FILE"

# ---------------- Helper functions ----------------

# Automatically detect WiFi interface
IFACE=$(iw dev | awk '$1=="Interface"{print $2; exit}')
[[ -z "$IFACE" ]] && zenity --error --text="No WiFi interface found!" && exit 1

get_saved_ssids() {
    jq -r 'keys[]' "$SAVE_FILE" 2>/dev/null
}

scan_networks() {
    iwctl station "$IFACE" scan >/dev/null 2>&1
    sleep 2

    iwctl station "$IFACE" get-networks \
        | tail -n +3 \
        | sed -r 's/\x1B\[[0-9;]*[mK]//g' \
        | awk '{$(NF-1)=$(NF)=""; print $0}' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -vE '^\s*$' \
        | sort -u
}


add_network() {
    SSID=$(scan_networks | zenity --list \
        --title="Available Networks" \
        --text="Select a network or type new" \
        --column="SSID" --editable)
    [[ -z "$SSID" ]] && return

    PASSWORD=$(zenity --entry --title="Password" \
        --text="Enter password for $SSID:" --hide-text)
    [[ -z "$PASSWORD" ]] && return

    jq --arg s "$SSID" --arg p "$PASSWORD" '. + {($s): $p}' "$SAVE_FILE" \
        > "$SAVE_FILE.tmp" && mv "$SAVE_FILE.tmp" "$SAVE_FILE"

    connect_network "$SSID"
}

remove_network() {
    SSID=$(zenity --list --title="Remove Network" --text="Select network to remove" \
        --column="Saved Networks" $(get_saved_ssids) --height=400 --width=300)
    [[ -z "$SSID" ]] && return
    jq "del(.\"$SSID\")" "$SAVE_FILE" > "$SAVE_FILE.tmp" && mv "$SAVE_FILE.tmp" "$SAVE_FILE"
    zenity --info --text="Removed network: $SSID"
}

change_password() {
    SSID=$(zenity --list --title="Change Password" --text="Select network" \
        --column="Saved Networks" $(get_saved_ssids) --height=400 --width=300)
    [[ -z "$SSID" ]] && return
    NEWPASS=$(zenity --entry --title="New Password" --text="Enter new password:" --hide-text)
    [[ -z "$NEWPASS" ]] && return
    jq --arg s "$SSID" --arg p "$NEWPASS" '.[$s]=$p' "$SAVE_FILE" \
        > "$SAVE_FILE.tmp" && mv "$SAVE_FILE.tmp" "$SAVE_FILE"
    zenity --info --text="Password updated for: $SSID"
}

connect_network() {
    SSID="$1"
    PASSWORD=$(jq -r --arg s "$SSID" '.[$s]' "$SAVE_FILE")
    zenity --question --title="Connect" --text="Connect to network: $SSID?"
    [[ $? -ne 0 ]] && return

    # Use expect to supply password to iwctl
    /usr/bin/expect <<EOF
spawn iwctl station "$IFACE" connect "$SSID"
expect "Passphrase:"
send "$PASSWORD\r"
expect eof
EOF

    zenity --info --text="Connected to $SSID"
}

# ---------------- Main menu ----------------

CHOICE=$(zenity --list \
    --title="WiFi Manager" \
    --text="Choose an action or network" \
    --column="Networks / Actions" "Add New" "Remove Network" "Change Password" $(get_saved_ssids) \
    --height=500 --width=400)

[[ -z "$CHOICE" ]] && exit 0

case "$CHOICE" in
    "Add New") add_network ;;
    "Remove Network") remove_network ;;
    "Change Password") change_password ;;
    *) connect_network "$CHOICE" ;;
esac

