#!/usr/bin/env bash

# Get current workspace ID
current=$(hyprctl activeworkspace -j | jq -r .id)

# Define previous and next
prev=$((current - 1))
next=$((current + 1))

# Build Ironbar-compatible JSON
echo "[
  {
    \"type\": \"button\",
    \"name\": \"workspace$prev\",
    \"class\": \"workspace\",
    \"label\": \"$prev\",
    \"on_click\": \"hyprctl dispatch workspace $prev\"
  },
  {
    \"type\": \"button\",
    \"name\": \"workspace$current\",
    \"class\": \"workspace current\",
    \"label\": \"$current\",
    \"on_click\": \"hyprctl dispatch workspace $current\"
  },
  {
    \"type\": \"button\",
    \"name\": \"workspace$next\",
    \"class\": \"workspace\",
    \"label\": \"$next\",
    \"on_click\": \"hyprctl dispatch workspace $next\"
  }
]"

