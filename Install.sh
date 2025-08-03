#!/bin/bash

set -e  # Exit if any command fails

# Optional: Enable debug output
# set -x

###-------------------------------
### Step 0: Update system keys and mirrors
###-------------------------------
echo ">>> [0/5] Updating keyring and mirrors..."
pacman -Sy --noconfirm archlinux-keyring

###-------------------------------
### Step 1: Install essential base system
###-------------------------------
echo ">>> [1/5] Installing base system and drivers..."
pacman -S --noconfirm --needed \
  base base-devel linux linux-headers linux-firmware \
  networkmanager nano fish git man-db efibootmgr \
  intel-ucode cpupower

###-------------------------------
### Step 2: Install audio & multimedia support
###-------------------------------
echo ">>> [2/5] Installing audio and multimedia tools..."
pacman -S --noconfirm --needed \
  pipewire pipewire-alsa pipewire-jack pipewire-pulse \
  libpulse alsa-plugins pavucontrol easyeffects cava ffmpegthumbnailer

###-------------------------------
### Step 3: Install Hyprland and UI essentials
###-------------------------------
echo ">>> [3/5] Installing Hyprland and Wayland apps..."
pacman -S --noconfirm --needed \
  hyprland hypridle hyprpicker hyprshot wl-clipboard slurp grim \
  fuzzel wlogout mako swww qt5-wayland qt5ct qt6ct gtk3-demos \
  qt5-tools qt6-tools xdg-desktop-portal xdg-desktop-portal-hyprland \
  polkit-gnome wireplumber libpulse

###-------------------------------
### Step 4: Install UI tools, fonts, themes
###-------------------------------
echo ">>> [4/5] Installing UI tools, fonts, and appearance..."
pacman -S --noconfirm --needed \
  kvantum bibata-cursor-theme \
  materia-gtk-theme adwaita-dark papirus-icon-theme noto-fonts \
  noto-fonts-cjk noto-fonts-emoji ttf-dejavu ttf-material-icons-git \
  ttf-material-symbols-variable-git ttf-nerd-fonts-symbols

###-------------------------------
### Step 5: Install extra apps and utilities
###-------------------------------
echo ">>> [5/5] Installing extra user apps and tools..."
pacman -S --noconfirm --needed \
  nemo nemo-fileroller gnome-keyring gnome-text-editor freedownloadmanager \
  visual-studio-code-bin youtube-music-bin zen-browser-bin yay yay-debug \
  glances playerctl tree jq eza starship yazi yt-dlp \
  ruby-fusuma ruby-fusuma-plugin-sendkey python-pywal16 tumbler \
  wget sshfs gammastep gamemode blueman bluez bluez-utils bluez-tools \
  kdeconnect speedtest-cli losslesscut-bin lutris \
  wine winetricks gparted ncdu wev cameractrls cloudflare-warp-bin rar

echo "✅ All packages installed successfully."

