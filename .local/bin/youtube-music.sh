#!/usr/bin/env bash
# Wrapper for youtube-music-bin — custom config + CSS

CONFIG_DIR="$HOME/.config/YouTube Music"
CONFIG_FILE="$CONFIG_DIR/config.json"
CSS_FILE="$CONFIG_DIR/custom-style.css"

# --- Ensure config directory exists ---
mkdir -p "$CONFIG_DIR"

# --- Inject your CSS (only if file exists) ---
# Replace this with your actual CSS from above
cat > "$CSS_FILE" <<'EOF'
/* --- YouTube Music Player Bar Custom Style --- */
#player-bar-background {
  background-color: transparent !important;
}
#progress-bar.ytmusic-player-bar {
  left: 0px !important;
  width: 100.6% !important;
  margin: 0px !important;
}
#sliderContainer.tp-yt-paper-slider {
  margin-left: 0px !important;
}
ytmusic-player-bar {
  background-color: rgba(0, 0, 0, 0.85) !important;
  backdrop-filter: blur(6px) !important;
  border-top: 1px solid rgba(255, 255, 255, 0.1) !important;
}
ytmusic-player-bar tp-yt-paper-progress,
ytmusic-player-bar .middle-controls,
ytmusic-player-bar .left-controls,
ytmusic-player-bar .right-controls {
  background: transparent !important;
}
ytmusic-nav-bar,
ytmusic-app-layout #nav-bar-background {
  border-bottom: none !important;
  box-shadow: none !important;
  background-color: transparent !important;
}
ytmusic-app-layout #guide-spacer,
ytmusic-app-layout #nav-bar-divider {
  background: transparent !important;
  border: none !important;
  box-shadow: none !important;
}
#mini-guide-background {
  border: none !important; 
}
ytmusic-nav-bar {
  display: flex !important;
  justify-content: flex-start !important;
  align-items: center !important;
  background: transparent !important;
  box-shadow: none !important;
  border: none !important;
  transition: background-color 0.3s ease, backdrop-filter 0.3s ease, transform 0.3s ease !important;
  backdrop-filter: none !important;
}
ytmusic-nav-bar > *:not(.left-content) {
  opacity: 0 !important;
  pointer-events: none !important;
  transition: opacity 0.3s ease !important;
}
ytmusic-nav-bar .left-content {
  display: flex !important;
  align-items: center !important;
  padding-left: 12px !important;
}
ytmusic-nav-bar .left-content > * {
  margin-right: 0.5rem !important;
}
ytmusic-nav-bar:hover {
  background-color: rgba(0, 0, 0, 0.6) !important;
  backdrop-filter: blur(10px) !important;
}
ytmusic-nav-bar:hover > *:not(.left-content) {
  opacity: 1 !important;
  pointer-events: auto !important;
}
EOF

# --- Apply permanent visual tweaks ---
jq '.visualTweaks.removeUpgradeButton = true
    | .visualTweaks.hideMenu = true
    | .customCSS = "'"$CSS_FILE"'"' \
    "$CONFIG_FILE" 2>/dev/null > "$CONFIG_FILE.tmp" || echo '{}' > "$CONFIG_FILE.tmp"
mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

# --- Launch the actual app ---
/usr/bin/youtube-music "$@"
