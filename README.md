# 🌐 Hyprland Arch Setup - Automated Dotfiles & Environment

A fully automated script to install, configure, and personalize your Arch Linux with Hyprland and a minimal Wayland-only desktop environment. This setup includes your custom dotfiles, essential utilities, UI themes, and personal preferences.

## 📦 What's Included?

- Fully scripted Arch install (no manual package entry)
- Wayland desktop with [Hyprland](https://github.com/hyprwm/Hyprland)
- Fish shell, Kitty terminal, Ironbar, Mako, Fuzzel, and more
- GTK/QT themes, Nerd Fonts, Bibata cursor, OneUI4 icons
- PipeWire + Bluetooth audio stack with EasyEffects
- Extra tools: Lutris, VS Code, Yazi, Zen Browser, MPV, Winetricks
- Optional: Autologin setup + Hyprland auto-start on tty1

## 🗂️ Repo Structure

Hyprland-dots/

├── .config/ → All configs (Hyprland, Ironbar, Fuzzel, Fish, etc.)  
├── .local/ → Local scripts, fish history, color schemes  
├── Install.sh → Main install and setup script  
└── README.md → You're here


## 📥 How to Use

### 1. Boot into Arch with internet (TTY)

This script is intended for a **fresh Arch Linux minimal install**.

### 2. Clone the repo

```
git clone https://github.com/yourusername/Hyprland-dots.git
cd Hyprland-dots
```
### 3. Run the installer script

```
chmod +x Install.sh
./Install.sh
```

You'll be prompted to enable autologin (optional).

### 🧰 What the Script Does

#### Step 0: Update keyring and mirrors

`
archlinux-keyring
`

#### Step 1: Install essential base system and firmware

`
base base-devel linux linux-headers linux-firmware
networkmanager nano fish git man-db efibootmgr
intel-ucode cpupower
`

#### Step 2: Install audio & multimedia stack

`
pipewire pipewire-alsa pipewire-jack pipewire-pulse libpulse
alsa-plugins pavucontrol easyeffects cava ffmpegthumbnailer
`

#### Step 3: Install Hyprland + Wayland apps

`
hyprland hypridle hyprpicker hyprshot wl-clipboard slurp grim
fuzzel wlogout mako swww qt5-wayland qt5ct qt6ct gtk3-demos
qt5-tools qt6-tools xdg-desktop-portal xdg-desktop-portal-hyprland
polkit-gnome wireplumber
`

#### Step 4: Install UI appearance tools

`
kvantum bibata-cursor-theme
materia-gtk-theme adwaita-dark papirus-icon-theme
noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu
ttf-material-icons-git ttf-material-symbols-variable-git ttf-nerd-fonts-symbols
`

#### Step 5: Install extra apps and tools

`
nemo nemo-fileroller gnome-keyring gnome-text-editor freedownloadmanager
visual-studio-code-bin youtube-music-bin zen-browser-bin yay yay-debug
glances playerctl tree jq eza starship yazi yt-dlp
ruby-fusuma ruby-fusuma-plugin-sendkey python-pywal16 tumbler
wget sshfs gammastep gamemode blueman bluez bluez-utils bluez-tools
kdeconnect speedtest-cli losslesscut-bin lutris wine winetricks
gparted ncdu wev cameractrls cloudflare-warp-bin rar
`

### 📂 Dotfiles Installation

The script automatically copies:

    All files from .config/ → ~/.config/

    All files from .local/ → ~/.local/

And makes the following scripts executable:

    ~/.config/ironbar/scripts/*

    ~/.config/hypr/hyprland/scripts/*

    ~/.local/bin/*

### 🔐 Autologin (Optional)

The script can optionally set up autologin on tty1 with:

`
/etc/systemd/system/getty@tty1.service.d/override.conf
`

Using agetty --autologin <user>
And it starts Hyprland automatically from your config.fish.
✅ Final Checks

Before finishing, the script checks via rfkill if:

    Wi-Fi is blocked

    Bluetooth is blocked

It warns you accordingly if anything is disabled.

