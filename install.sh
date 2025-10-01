#!/usr/bin/env bash
# Install.sh – Arch post-install automation (Hyprland, Ironbar, etc.)
# Safe, idempotent, modular, resumable
set -euo pipefail


#============================#
#        ENTRY POINT         #
#============================#
SKIPPED=0
EXTRAS=0
GAMING=0
NO_FONTS=0
NO_THEMES=0
NO_ICONS=0
STAGE="all"


#============================#
#         CONFIG             #
#============================#
DOTS_DIR="$(pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

CORE_PKGS=(
  base base-devel git fish wget curl unzip zip rsync
  hyprland hyprlock hypridle kitty fuzzel
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol
  brightnessctl bluez bluez-utils iwd
  starship eza ripgrep fd jq
  swww nemo nemo-fileroller nano
  ffmpeg mako gnome-text-editor gst-libav gst-plugins-good gst-plugins-bad
  vlc vlc-plugins-all mission-center gnome-keyring python-gobject
)

EXTRA_PKGS=(
  yt-dlp gallery-dl
)
EXTRA_AUR_PKGS=(
  youtube-music-bin
  tor-browser-bin
  gallery-dl
)

GAMING_PKGS=(
  steam lutris wine winetricks mangohud goverlay gamemode protonup-qt
)

AUR_PKGS=(
  ironbar-git rar ncdu zen-browser-bin
  hyprshot cliphist wlogout wallust xdotool eog visual-studio-code-bin
  ruby-fusuma ruby-fusuma-plugin-sendkey
)

FONTS_PKGS=(
  ttf-dejavu
  ttf-jetbrains-mono-nerd
  ttf-nerd-fonts-symbols
  noto-fonts
  noto-fonts-cjk
  noto-fonts-emoji
)

FONTS_AUR_PKGS=(
  ttf-material-icons-git
  ttf-material-symbols-variable-git
)

ICON_AUR_PKGS=(
  illogical-impulse-oneui4-icons-git
)

THEME_PKGS=(
  kvantum
  materia-gtk-theme
)

THEME_AUR_PKGS=(
  kvantum-qt5
  kvantum-theme-materia
  bibata-cursor-theme
)

#============================#
#         HELPERS            #
#============================#
log()    { echo -e "\e[1;32m[INFO]\e[0m $*"; }
warn()   { echo -e "\e[1;33m[WARN]\e[0m $*"; }
error()  { echo -e "\e[1;31m[ERR ]\e[0m $*" >&2; }
prompt() { read -rp "[?] $1 [y/N]: " r; [[ $r =~ ^[Yy]$ ]]; }

safe_run() {
  local desc="${*: -1}"
  local cmd=("${@:1:$#-1}")

  while true; do
    if "${cmd[@]}"; then
      log "✅ $desc"
      return 0
    else
      echo -e "\e[1;31m[ERROR]\e[0m '$desc' failed."
      echo "Choose: [s]kip, [r]etry, [a]bort"
      read -rp "Enter your choice: " choice
      case "$choice" in
        s|S) warn "Skipping '$desc'."; SKIPPED=1; return 0 ;;
        r|R) log "Retrying '$desc'…" ;;
        a|A) error "Aborting installation."; exit 1 ;;
        *) warn "Invalid choice, please select s/r/a." ;;
      esac
    fi
  done
}

#============================#
#  PRE-NETWORK FIX           #
#============================#
pre_network_fix() {
  log "💾 Installing nano and fixing /etc/resolv.conf"
  sudo pacman -S --needed --noconfirm nano
  echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee /etc/resolv.conf >/dev/null
}

#============================#
#     CONNECTIVITY CHECK     #
#============================#
check_internet() {
  log "🔍 Checking internet connectivity…"
  if ! ping -c 1 archlinux.org &>/dev/null; then
    warn "No internet detected. Attempting to start DHCP for Ethernet…"
    setup_ethernet_dhcp
    sleep 3
    if ! ping -c 1 archlinux.org &>/dev/null; then
      error "Still no internet. Please fix network manually."
      exit 1
    fi
  fi
}

#============================#
#  ETHERNET DHCP SETUP       #
#============================#
setup_ethernet_dhcp() {
  log "🖧 Setting up systemd-networkd for Ethernet…"

  ETH_IFACE=$(ip -o link show | awk -F': ' '/en|eth/{print $2}' | head -n1)
  if [[ -n "$ETH_IFACE" ]]; then
    NET_FILE="/etc/systemd/network/20-wired.network"
    if [[ ! -f "$NET_FILE" ]]; then
      log "Creating minimal networkd config for $ETH_IFACE"
      echo -e "[Match]\nName=$ETH_IFACE\n\n[Network]\nDHCP=yes" | \
        sudo tee "$NET_FILE" >/dev/null
    fi

    safe_run sudo systemctl enable --now systemd-networkd "Enabling systemd-networkd"
    safe_run sudo systemctl enable --now systemd-resolved "Enabling systemd-resolved"
    safe_run sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf "Linking resolv.conf"
  else
    warn "No Ethernet interface found; cannot setup DHCP automatically"
  fi
}

#============================#
#   SYSTEM UPDATE + MIRRORS  #
#============================#
system_prep() {
  safe_run sudo pacman -Syyu --noconfirm "Updating system package database"
  if ! pacman -Q reflector &>/dev/null; then
    safe_run sudo pacman -S --needed --noconfirm reflector "Installing reflector"
  fi
  safe_run sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist "Optimizing mirrors with reflector"
}

#============================#
#   PACMAN & AUR INSTALLER   #
#============================#
install_pkgs() {
  sudo pacman -S --needed --noconfirm "$@"
}

ensure_yay() {
  if ! command -v yay &>/dev/null; then
    safe_run bash -c 'tmpdir=$(mktemp -d); git clone https://aur.archlinux.org/yay.git "$tmpdir" && pushd "$tmpdir" && makepkg -si --noconfirm && popd && rm -rf "$tmpdir"' "Installing yay (AUR helper)"
  else
    log "👍 yay already installed."
  fi
}

update_yay() {
  ensure_yay
  safe_run yay -Syu --noconfirm "Updating AUR packages and dependencies"
}

install_aur() {
  local pkgs=("$@")
  local virt
  virt=$(systemd-detect-virt || true)

  if [[ "$virt" == "none" ]]; then
    log "🏗️ Bare metal detected – using yay for AUR packages."
    ensure_yay
    # skip integrity checks, fully non-interactive
    safe_run yay -S --needed --noconfirm --mflags "--skipinteg --noprogressbar" "${pkgs[@]}" \
      "Installing AUR packages: ${pkgs[*]}"
  else
    log "💻 VM detected ($virt) – building AUR packages sequentially."
    safe_run sudo pacman -S --needed --noconfirm git base-devel "Installing build tools for AUR"
    for pkg in "${pkgs[@]}"; do
      safe_run bash -c "
        tmpdir=\$(mktemp -d) &&
        git clone https://aur.archlinux.org/$pkg.git \$tmpdir &&
        cd \$tmpdir &&
        makepkg -si --noconfirm &&
        cd - &&
        rm -rf \$tmpdir
      " "Building AUR package: $pkg"
    done
  fi
}


#============================#
#        DOTFILES SYNC       #
#============================#
sync_dotfiles() {
  safe_run rsync -avh --backup --suffix="$BACKUP_SUFFIX" \
    --exclude ".git" \
    --exclude "README.md" \
    --exclude "Install.sh" \
    "$DOTS_DIR"/.config/ "$HOME/.config/" \
    "Syncing dotfiles to ~/.config"

  if [[ -d "$DOTS_DIR/.local" ]]; then
    safe_run rsync -avh --backup --suffix="$BACKUP_SUFFIX" \
      "$DOTS_DIR/.local/" "$HOME/.local/" \
      "Syncing local files to ~/.local"
  fi

  mkdir -p "$HOME/Pictures"
  log "📁 Ensured $HOME/Pictures exists"

  if [[ -d "$DOTS_DIR/Pictures" ]]; then
    safe_run rsync -avh --backup --suffix="$BACKUP_SUFFIX" \
      "$DOTS_DIR/Pictures/" "$HOME/Pictures/" \
      "Syncing Pictures folder"
  fi
}


#============================#
#     SHELL CONFIG           #
#============================#
set_fish_shell() {
  safe_run bash -c "grep -q \"$(command -v fish)\" /etc/shells || echo \"$(command -v fish)\" | sudo tee -a /etc/shells" "Adding fish to /etc/shells"
  if [[ $SHELL != *fish ]]; then
    safe_run chsh -s "$(command -v fish)" "Changing default shell to fish"
  fi
}

#============================#
#     SYSTEMD SERVICES       #
#============================#
setup_user_services() {
  safe_run systemctl --user daemon-reload "Reloading user systemd daemon"
}

setup_system_services() {
  if systemctl is-active --quiet NetworkManager.service; then
    safe_run sudo systemctl disable --now NetworkManager.service "Disabling NetworkManager.service"
  fi

  IWD_CONF_DIR="/etc/iwd"
  IWD_CONF_FILE="$IWD_CONF_DIR/main.conf"
  if [[ ! -d "$IWD_CONF_DIR" ]]; then
    safe_run sudo mkdir -p "$IWD_CONF_DIR" "Creating iwd config directory"
  fi
  if [[ ! -f "$IWD_CONF_FILE" ]]; then
    safe_run bash -c "echo -e \"[General]\nEnableNetworkConfiguration=true\" | sudo tee \"$IWD_CONF_FILE\" >/dev/null" "Creating minimal iwd config"
  fi

  safe_run sudo systemctl enable --now iwd.service "Enabling iwd.service"

  if [[ -f "$DOTS_DIR/systemd/system/bluetooth-autofix.service" ]]; then
    safe_run bash -c "sudo cp \"$DOTS_DIR/systemd/system/bluetooth-autofix.service\" /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable bluetooth-autofix.service" "Installing bluetooth-autofix.service"
  else
    warn "bluetooth-autofix.service not found in repo!"
  fi
}

#============================#
#  AUTOLOGIN SETUP           #
#============================#
setup_autologin() {
  local user="$USER"
  local service_dir="/etc/systemd/system/getty@tty1.service.d"
  local override_file="$service_dir/override.conf"

  log "🔑 Setting up autologin for user '$user' on tty1"
  sudo mkdir -p "$service_dir"
  echo -e "[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin $user %I \$TERM >/dev/null 2>&1" | sudo tee "$override_file" >/dev/null
  sudo systemctl daemon-reexec
}

install_fusuma() {
  if groups "$USER" | grep -qw input; then
    log "✅ $USER is already in the input group"
  else
    safe_run sudo gpasswd -a "$USER" input "Adding $USER to input group"
    log "ℹ️ Please log out and back in (or reboot) for input group changes to apply."
  fi
}



setup_icons() {
  if [[ $NO_ICONS -eq 0 ]] && pacman -Q illogical-impulse-oneui4-icons-git &>/dev/null; then
    if command -v gsettings &>/dev/null; then
      safe_run gsettings set org.gnome.desktop.interface icon-theme "OneUI-dark" \
        "Setting GNOME icon theme to OneUI-dark"
    else
      warn "gsettings not found – skipping icon theme setup"
    fi
  else
    log "⏭️ Skipping icon setup (--no-icons or package missing)"
  fi
}

#============================#
#   CPU GOVERNOR AUTO-SWITCH #
#============================#
setup_cpu_governor() {
log "⚡ Setting up CPU governor auto-switch (AC vs Battery)"

# Script to set governor

cat <<'EOF' | sudo tee /usr/local/bin/set-governor.sh >/dev/null
#!/bin/sh
STATUS=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null)

if echo "$STATUS" | grep -Eq "Charging|Not charging"; then
AC_ON=1
else
AC_ON=0
fi

AVAILABLE=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)

if echo "$AVAILABLE" | grep -qw performance; then
PERF="performance"
else
PERF=$(echo "$AVAILABLE" | awk '{print $1}')
fi

if echo "$AVAILABLE" | grep -qw powersave; then
SAVE="powersave"
else
SAVE="$PERF"
fi

for c in /sys/devices/system/cpu/cpu[0-9]*; do
if [ -f "$c/cpufreq/scaling_governor" ]; then
if [ "$AC_ON" = "1" ]; then
echo "$PERF" > "$c/cpufreq/scaling_governor"
logger "Governor set to $PERF (AC connected: $STATUS)"
else
echo "$SAVE" > "$c/cpufreq/scaling_governor"
logger "Governor set to $SAVE (on battery: $STATUS)"
fi
fi
done
EOF

sudo chmod +x /usr/local/bin/set-governor.sh

# Udev rules

cat <<'EOF' | sudo tee /etc/udev/rules.d/99-governor.rules >/dev/null
ACTION=="change", SUBSYSTEM=="power_supply", RUN+="/usr/local/bin/set-governor.sh"
EOF

# Systemd unit

cat <<'EOF' | sudo tee /etc/systemd/system/set-governor.service >/dev/null
[Unit]
Description=Set CPU governor based on AC or Battery
After=basic.target
Before=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-governor.sh

[Install]
WantedBy=multi-user.target
EOF

# Enable and run once

sudo systemctl daemon-reload
sudo systemctl enable set-governor.service
sudo /usr/local/bin/set-governor.sh
}

#============================#
#        MAIN STAGES         #
#============================#
stage_pkgs() {
  safe_run system_prep "Updating system and optimizing mirrors"
  safe_run install_pkgs "${CORE_PKGS[@]}" "Installing core packages"

  if [[ $NO_FONTS -eq 0 ]]; then
    safe_run install_pkgs "${FONTS_PKGS[@]}" "Installing fonts"
    [[ ${#FONTS_AUR_PKGS[@]} -gt 0 ]] && safe_run install_aur "${FONTS_AUR_PKGS[@]}" "Installing AUR fonts"
  else
    log "⏭️ Skipping fonts (--no-fonts)"
  fi

  if [[ $NO_THEMES -eq 0 ]]; then
    safe_run install_pkgs "${THEME_PKGS[@]}" "Installing themes"
    [[ ${#THEME_AUR_PKGS[@]} -gt 0 ]] && safe_run install_aur "${THEME_AUR_PKGS[@]}" "Installing AUR themes"
  else
    log "⏭️ Skipping themes (--no-themes)"
  fi
  
  if [[ $NO_ICONS -eq 0 ]]; then
    [[ ${#ICON_AUR_PKGS[@]} -gt 0 ]] && safe_run install_aur "${ICON_AUR_PKGS[@]}" "Installing icon AUR packages"
    setup_icons
  else
    log "⏭️ Skipping icons (--no-icons)"
  fi

  [[ ${#AUR_PKGS[@]} -gt 0 ]] && safe_run install_aur "${AUR_PKGS[@]}" "Installing AUR packages"

  if [[ $EXTRAS -eq 1 ]]; then
    [[ ${#EXTRA_PKGS[@]} -gt 0 ]] && safe_run install_pkgs "${EXTRA_PKGS[@]}" "Installing extra packages"
    [[ ${#EXTRA_AUR_PKGS[@]} -gt 0 ]] && safe_run install_aur "${EXTRA_AUR_PKGS[@]}" "Installing extra AUR packages"
  fi

  if [[ $GAMING -eq 1 ]]; then
    safe_run install_pkgs "${GAMING_PKGS[@]}" "Installing gaming packages"
  fi
}

stage_dotfiles() {
  safe_run sync_dotfiles "Syncing dotfiles"
  safe_run set_fish_shell "Configuring fish shell"
}

stage_services() {
  safe_run setup_system_services "Configuring system services"
  safe_run setup_user_services "Reloading user services"
  safe_run setup_autologin "Setting up autologin for current user"
  safe_run install_fusuma "🎹 Setting up Fusuma input permissions"
  safe_run setup_cpu_governor "⚡ Setting up CPU governor auto-switch"
}

#============================#
#   BOOTLOADER OPTIMIZATION  #
#============================#
optimize_bootloader() {
  if grep -q '^timeout' /boot/loader/loader.conf; then
    sudo sed -i 's/^timeout.*/timeout 0/' /boot/loader/loader.conf
  else
    echo "timeout 0" | sudo tee -a /boot/loader/loader.conf >/dev/null
  fi
}

set_default_terminal() {
  if command -v gsettings &>/dev/null; then
    safe_run gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty "Setting Kitty as default terminal"
    safe_run gsettings set org.cinnamon.desktop.default-applications.terminal exec-arg '' "Clearing Kitty exec-arg"
  fi
  safe_run xdg-mime default kitty.desktop x-scheme-handler/terminal "Setting Kitty as terminal in xdg-mime"
}

print_help() {
  cat <<EOF
Usage: $0 [options] [stage]

Stages:
  pkgs        Install packages (core, fonts, themes, icons, extras, gaming)
  dotfiles    Sync dotfiles and configure shell
  services    Configure system/user services, autologin, bootloader, terminal
  all         Run everything (default)

Options:
  -a, --all          Run all stages (default)
  -e, --extras       Include extra packages (yt-dlp, youtube-music, etc.)
  -g, --gaming       Include gaming packages (Steam, Lutris, Wine, etc.)
  -f, --no-fonts     Skip installing fonts
  -t, --no-themes    Skip installing themes
  -i, --no-icons     Skip installing icons
  -h, --help         Show this help message

Examples:
  $0 pkgs -e          Install pkgs + extras
  $0 dotfiles -f -t   Sync dotfiles but skip fonts and themes
  $0 -eg              Install all with extras + gaming
  $0 -fti             Run all but skip fonts, themes, and icons
EOF
}

if [[ $EUID -eq 0 ]]; then
  error "Run as user, not root."
  exit 1
fi

sudo -v
( while true; do sudo -n true; sleep 60; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null || true' EXIT

while [[ $# -gt 0 ]]; do
  case $1 in
    # Long flags
    --extras) EXTRAS=1 ;;
    --gaming) GAMING=1 ;;
    --no-fonts) NO_FONTS=1 ;;
    --no-themes) NO_THEMES=1 ;;
    --no-icons) NO_ICONS=1 ;;
    --all) STAGE="all" ;;
    --help) print_help; exit 0 ;;

    # Short flags
    -a) STAGE="all" ;;
    -e) EXTRAS=1 ;;
    -g) GAMING=1 ;;
    -f) NO_FONTS=1 ;;
    -t) NO_THEMES=1 ;;
    -i) NO_ICONS=1 ;;
    -h) print_help; exit 0 ;;
    -[aegfti]*) # Combined short flags like -egti
      for ((i=1; i<${#1}; i++)); do
        case "${1:$i:1}" in
          a) STAGE="all" ;;
          e) EXTRAS=1 ;;
          g) GAMING=1 ;;
          f) NO_FONTS=1 ;;
          t) NO_THEMES=1 ;;
          i) NO_ICONS=1 ;;
          h) print_help; exit 0 ;;
          *) error "Unknown short option: -${1:$i:1}"; exit 1 ;;
        esac
      done
      ;;

    # Stages
    pkgs|dotfiles|services|all) STAGE=$1 ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

case $STAGE in
  pkgs)      stage_pkgs ;;
  dotfiles)  stage_dotfiles ;;
  services)  stage_services; optimize_bootloader; set_default_terminal ;;
  all)       stage_pkgs; stage_dotfiles; stage_services ;;
esac

if [[ $SKIPPED -eq 1 ]]; then
  warn "⚠️  Completed with skipped steps"
  STATUS=2
else
  log "✅ Post-install stage [$STAGE] complete!"
  STATUS=0
fi

if [[ $STAGE == "all" ]]; then
  if prompt "Reboot now to apply changes?"; then
    log "Rebooting…"
    sudo reboot
  else
    log "Reboot skipped. Please reboot manually later."
  fi
fi

exit $STATUS

