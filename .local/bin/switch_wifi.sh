#!/bin/bash

SSID="$1"
PSK="$2"

wpa_cli remove_network 0
wpa_cli add_network
wpa_cli set_network 0 ssid "\"$SSID\""
wpa_cli set_network 0 psk "\"$PSK\""
wpa_cli enable_network 0
wpa_cli save_config
wpa_cli quit

