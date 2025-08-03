#!/bin/bash

set -e  # Exit on error
# set -x  # Uncomment to debug

###-------------------------------
### Pre-check: Prevent root execution
###-------------------------------
if [ "$EUID" -eq 0 ]; then
  echo "❌ Please run this script as a regular user (not root)."
  exit 1
fi

###-------------------------------
### Step 0: Update keyring and mirrors
###-------------------------------
echo ">>> [0/5] Updating keyring and mirrors..."
sudo pacman -Sy --noconfirm archlinux-keyring

###-------------------------------
### Step 1: Install essential base system
###-------------------------------
echo ">>> [1/5] Installing base system and drivers..."
sudo pacman -S --noconfirm --needed \
  base base-devel linux linux-headers linux-firmware \
  networkmanager nano fish git man-db efibootmgr \
  intel-ucode cpupower

###-------------------------------
### Step 2: Install audio & multimedia support
###-------------------------------
echo ">>> [2/5] Installing audio and multimedia tools..."
sudo pacman -S --noconfirm --needed \
  pipewire pipewire-alsa pipewire-jack pipewire-pulse \
  libpulse alsa-plugins pavucontrol easyeffects cava ffmpegthumbnailer

###-------------------------------
### Step 3: Install Hyprland and Wayland essentials
###-------------------------------
echo ">>> [3/5] Installing Hyprland and Wayland apps..."
sudo pacman -S --noconfirm --needed \
  hyprland hypridle hyprpicker hyprshot wl-clipboard slurp grim \
  fuzzel wlogout mako swww qt5-wayland qt5ct qt6ct gtk3-demos \
  qt5-tools qt6-tools xdg-desktop-portal xdg-desktop-portal-hyprland \
  polkit-gnome wireplumber libpulse

###-------------------------------
### Step 4: Install UI tools, fonts, themes
###-------------------------------
echo ">>> [4/5] Installing UI tools, fonts, and appearance..."
sudo pacman -S --noconfirm --needed \
  kvantum bibata-cursor-theme \
  materia-gtk-theme adwaita-dark papirus-icon-theme noto-fonts \
  noto-fonts-cjk noto-fonts-emoji ttf-dejavu ttf-material-icons-git \
  ttf-material-symbols-variable-git ttf-nerd-fonts-symbols

###-------------------------------
### Step 5: Install extra user apps and utilities
###-------------------------------
echo ">>> [5/5] Installing extra user apps and tools..."
sudo pacman -S --noconfirm --needed \
  nemo nemo-fileroller gnome-keyring gnome-text-editor freedownloadmanager \
  visual-studio-code-bin youtube-music-bin zen-browser-bin yay yay-debug \
  glances playerctl tree jq eza starship yazi yt-dlp \
  ruby-fusuma ruby-fusuma-plugin-sendkey python-pywal16 tumbler \
  wget sshfs gammastep gamemode blueman bluez bluez-utils bluez-tools \
  kdeconnect speedtest-cli losslesscut-bin lutris \
  wine winetricks gparted ncdu wev cameractrls cloudflare-warp-bin rar

echo "✅ All packages installed successfully."

###-------------------------------
### Step 6: Copy dotfiles to user home
###-------------------------------
echo ">>> Copying dotfiles to ~/.config and ~/.local..."

mkdir -p ~/.config ~/.local

cp -rf .config/* ~/.config/
cp -rf .local/* ~/.local/

# Make all user scripts executable
find ~/.config/ironbar/scripts -type f -exec chmod +x {} \; || true
find ~/.config/hypr/hyprland/scripts -type f -exec chmod +x {} \; || true
find ~/.local/bin -type f -exec chmod +x {} \; || true

echo "✅ Dotfiles copied successfully."

###-------------------------------
### Step 7: Install and activate OneUI4 Icons
###-------------------------------
echo "🎨 Installing OneUI4 Icons..."

# Clone the icon theme repository
git clone https://github.com/mjkim0727/OneUI4-Icons.git /tmp/OneUI4-Icons

# Create ~/.icons if it doesn't exist
mkdir -p ~/.icons

# Move the dark variant to ~/.icons
mv /tmp/OneUI4-Icons/OneUI-dark ~/.icons/

# Clean up
rm -rf /tmp/OneUI4-Icons

# Apply the icon theme using gsettings (if available)
if command -v gsettings &> /dev/null; then
  gsettings set org.gnome.desktop.interface icon-theme "One UI Icon Theme"
  echo "✅ One UI Icon Theme applied using gsettings."
else
  echo "⚠️  gsettings not found. You may need to manually set the icon theme."
fi


###-------------------------------
### Step 8: Set fish as default shell
###-------------------------------
if ! echo "$SHELL" | grep -q fish; then
  echo "💡 Setting fish as default shell for $USER..."
  chsh -s /usr/bin/fish
fi

###-------------------------------
### Step 9: Setup autologin on tty1
###-------------------------------
read -p "❓ Do you want to enable autologin on tty1? [y/N]: " enable_autologin
if [[ "$enable_autologin" =~ ^[Yy]$ ]]; then
  echo ">>> Autologin requested."

  read -p "🔍 Use current user '$USER'? [Y/n]: " use_current
  if [[ "$use_current" =~ ^[Nn]$ ]]; then
    read -p "👤 Enter the username to autologin: " custom_user
    AUTOLOGIN_USER="$custom_user"
  else
    AUTOLOGIN_USER="$USER"
  fi

  echo "⚙️  Configuring autologin for: $AUTOLOGIN_USER"

  TTY_SERVICE="/etc/systemd/system/getty@tty1.service.d"
  sudo mkdir -p "$TTY_SERVICE"
  sudo tee "$TTY_SERVICE/override.conf" > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $AUTOLOGIN_USER --noclear %I \$TERM
EOF

  echo "✅ Autologin configured for '$AUTOLOGIN_USER' on tty1."
else
  echo "⏭️ Skipping autologin setup."
fi

###-------------------------------
### Step 10: Check rfkill status
###-------------------------------
echo ">>> Checking wireless and Bluetooth block status..."
if ! command -v rfkill &> /dev/null; then
  echo "🔧 Installing rfkill..."
  sudo pacman -S --noconfirm rfkill
fi

rfkill list | grep -iE "bluetooth|wlan|wifi" || echo "⚠️  rfkill output not found."
echo "ℹ️ If any device is 'Soft blocked: yes', run: sudo rfkill unblock all"

echo "🎉 Setup complete. You can now reboot into Hyprland!"

