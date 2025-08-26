#!/usr/bin/env bash
# Arch system cleanup script
# Usage: ./cleanup.sh

echo "Starting system cleanup..."

# 1. Remove cached packages from pacman (except the latest)
echo "Cleaning pacman cache..."
sudo pacman -Sc --noconfirm

# 2. Remove yay cache
echo "Cleaning yay cache..."
rm -rf ~/.cache/yay/*

# 3. Remove unused Flatpak runtimes
echo "Cleaning unused Flatpak runtimes..."
flatpak uninstall --unused -y

# 4. Remove thumbnails cache
if [[ -d "$HOME/.cache/thumbnails" ]]; then
    echo "Cleaning thumbnail cache..."
    rm -rf ~/.cache/thumbnails/*
fi

# 5. Remove temporary files
echo "Cleaning /tmp..."
sudo rm -rf /tmp/*

# 6. Clear journal logs older than 2 weeks
echo "Cleaning old journal logs..."
sudo journalctl --vacuum-time=2weeks

# 7. Optional: clean browser cache if using Firefox/Chrome
echo "Cleaning Zen Browser cache..."
rm -rf ~/.cache/zen/*/cache2

# echo "Cleaning Chromium/Chrome cache..."
# rm -rf ~/.cache/chromium/* ~/.cache/google-chrome/*

echo "System cleanup completed!"

