#!/bin/bash

cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')
mem=$(free | awk '/Mem:/ {print int($3/$2 * 100)}')
temp=$(sensors | awk '/Package id 0:/ {print int($4)}' | tr -d '+°C')

label="  ${cpu}%"

if (( mem > 50 )); then
  label+=" |   ${mem}%"
fi

if (( temp > 65 )); then
  label+=" |   ${temp}°C"
fi


echo "$label"
