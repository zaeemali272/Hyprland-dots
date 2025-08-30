#!/usr/bin/env bash
# Install.sh – Arch post-install automation (Hyprland, Ironbar, etc.)
# Safe, idempotent, modular, resumable
set -euo pipefail

#============================#
#         CONFIG             #
#============================#
DOTS_DIR="$(pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

CORE_PKGS=(
  base base-devel git fish neovim wget curl unzip zip rsync
  hyprland kitty fuzzel
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol
  brightnessctl bluez bluez-utils iwd dhcpcd
  starship eza ripgrep fd jq kvantum materia-gtk-theme
)

EXTRA_PKGS=( ncdu rar unzip )
GAMING_PKGS=( steam lutris wine winetricks mangohud goverlay gamemode )
AUR_PKGS=( ironbar-git kvantum-qt5 kvantum-theme-materia )

#============================#
#         HELPERS            #
#============================#
log()    { echo -e "\e[1;32m[INFO]\e[0m $*"; }
warn()   { echo -e "\e[1;33m[WARN]\e[0m $*"; }
error()  { echo -e "\e[1;31m[ERR ]\e[0m $*" >&2; }
prompt() { read -rp "[?] $1 [y/N]: " r; [[ $r =~ ^[Yy]$ ]]; }

safe_run() {
  local cmd="$1"
  local desc="$2"
  while true; do
    eval "$cmd" && break || true
    echo -e "\e[1;31m[ERROR]\e[0m '$desc' failed."
    echo "Choose: [s]kip, [r]etry, [a]bort"
    read -rp "Enter your choice: " choice
    case "$choice" in
      s|S) warn "Skipping '$desc'."; break ;;
      r|R) log "Retrying '$desc'…" ;;
      a|A) error "Aborting installation."; exit 1 ;;
      *) warn "Invalid choice, please select s/r/a." ;;
    esac
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
  log "🖧 Setting up systemd-networkd + dhcpcd for Ethernet…"

  # Enable dhcpcd service for all Ethernet interfaces
  safe_run "sudo systemctl enable --now dhcpcd" "Enabling dhcpcd service"

  # Fallback: systemd-networkd config
  ETH_IFACE=$(ip -o link show | awk -F': ' '/en|eth/{print $2}' | head -n1)
  if [[ -n "$ETH_IFACE" ]]; then
    NET_FILE="/etc/systemd/network/20-wired.network"
    if [[ ! -f "$NET_FILE" ]]; then
      log "Creating minimal networkd config for $ETH_IFACE"
      echo -e "[Match]\nName=$ETH_IFACE\n\n[Network]\nDHCP=yes" | sudo tee "$NET_FILE" >/dev/null
      safe_run "sudo systemctl enable --now systemd-networkd" "Enabling systemd-networkd"
      safe_run "sudo systemctl enable --now systemd-resolved" "Enabling systemd-resolved"
      safe_run "sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf" "Linking resolv.conf"
    fi
  else
    warn "No Ethernet interface found; cannot setup DHCP automatically"
  fi
}

#============================#
#   SYSTEM UPDATE + MIRRORS  #
#============================#
system_prep() {
  safe_run "sudo pacman -Syyu --noconfirm" "Updating system package database"
  if ! pacman -Q reflector &>/dev/null; then
    safe_run "sudo pacman -S --needed --noconfirm reflector" "Installing reflector"
  fi
  safe_run "sudo reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist" "Optimizing mirrors with reflector"
}

#============================#
#   PACMAN & AUR INSTALLER   #
#============================#
install_pkgs() {
  local pkgs=("$@")
  safe_run "sudo pacman -Syu --needed --noconfirm \"\${pkgs[@]}\"" "Installing packages: ${pkgs[*]}"
}

ensure_yay() {
  if ! command -v yay &>/dev/null; then
    safe_run "tmpdir=\$(mktemp -d); git clone https://aur.archlinux.org/yay.git \"\$tmpdir\"; pushd \"\$tmpdir\"; makepkg -si --noconfirm; popd; rm -rf \"\$tmpdir\"" "Installing yay (AUR helper)"
  else
    log "👍 yay already installed."
  fi
}

update_yay() {
  ensure_yay
  safe_run "yay -Syu --noconfirm" "Updating AUR packages and dependencies"
}

install_aur() {
  local pkgs=("$@")
  local virt
  virt=$(systemd-detect-virt || true)

  if [[ "$virt" == "none" ]]; then
    log "🏗️ Bare metal detected – using yay for AUR packages."
    ensure_yay
    safe_run "yay -S --needed --noconfirm \"\${pkgs[@]}\"" "Installing AUR packages: ${pkgs[*]}"
  else
    log "💻 VM detected ($virt) – using makepkg directly for AUR packages."
    safe_run "sudo pacman -S --needed --noconfirm git base-devel" "Installing build tools"
    for pkg in "${pkgs[@]}"; do
      safe_run "git clone https://aur.archlinux.org/$pkg.git /tmp/$pkg && cd /tmp/$pkg && makepkg -si --noconfirm && cd -" "Building $pkg from AUR"
    done
  fi
}

#============================#
#        DOTFILES SYNC       #
#============================#
sync_dotfiles() {
  safe_run "rsync -avh --backup --suffix=\"$BACKUP_SUFFIX\" --exclude \".git\" --exclude \"README.md\" --exclude \"Install.sh\" \"$DOTS_DIR\"/.config/ \"$HOME/.config/\"" "Syncing dotfiles to ~/.config"

  if [[ -d "$DOTS_DIR/.icons" ]]; then
    safe_run "rsync -avh --backup --suffix=\"$BACKUP_SUFFIX\" \"$DOTS_DIR/.icons/\" \"$HOME/.icons/\"" "Syncing icons to ~/.icons"
    shopt -s nullglob
    for zipfile in "$HOME/.icons"/*.zip; do
      safe_run "unzip -o \"$zipfile\" -d \"$HOME/.icons/\" && rm -f \"$zipfile\"" "Extracting icon archive: $(basename "$zipfile")"
    done
    shopt -u nullglob
  fi

  if [[ -d "$DOTS_DIR/.local" ]]; then
    safe_run "rsync -avh --backup --suffix=\"$BACKUP_SUFFIX\" \"$DOTS_DIR/.local/\" \"$HOME/.local/\"" "Syncing local files to ~/.local"
  fi

  # ✅ Create Pictures folder
  mkdir -p "$HOME/Pictures"
  log "📁 Created $HOME/Pictures folder"
}

#============================#
#     SHELL CONFIG           #
#============================#
set_fish_shell() {
  safe_run "grep -q \"$(command -v fish)\" /etc/shells || echo \"$(command -v fish)\" | sudo tee -a /etc/shells" "Adding fish to /etc/shells"
  if [[ $SHELL != *fish ]]; then
    safe_run "chsh -s \"$(command -v fish)\"" "Changing default shell to fish"
  fi
}

#============================#
#     SYSTEMD SERVICES       #
#============================#
setup_user_services() {
  safe_run "systemctl --user daemon-reload" "Reloading user systemd daemon"
}

setup_system_services() {
  if systemctl is-active --quiet NetworkManager.service; then
    safe_run "sudo systemctl disable --now NetworkManager.service" "Disabling NetworkManager.service"
  fi

  IWD_CONF_DIR="/etc/iwd"
  IWD_CONF_FILE="$IWD_CONF_DIR/main.conf"
  if [[ ! -d "$IWD_CONF_DIR" ]]; then
    safe_run "sudo mkdir -p \"$IWD_CONF_DIR\"" "Creating iwd config directory"
  fi
  if [[ ! -f "$IWD_CONF_FILE" ]]; then
    safe_run "echo -e \"[General]\nEnableNetworkConfiguration=true\" | sudo tee \"$IWD_CONF_FILE\" >/dev/null" "Creating minimal iwd config"
  fi

  # ✅ Always enable iwd.service, even if Wi-Fi is not present
  safe_run "sudo systemctl enable --now iwd.service" "Enabling iwd.service"

  if [[ -f "$DOTS_DIR/systemd/system/bluetooth-autofix.service" ]]; then
    safe_run "sudo cp \"$DOTS_DIR/systemd/system/bluetooth-autofix.service\" /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable bluetooth-autofix.service" "Installing bluetooth-autofix.service"
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
  
  # Create directory if missing
  sudo mkdir -p "$service_dir"

  # Write override.conf
  echo -e "[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin $user %I \$TERM >/dev/null 2>&1" | sudo tee "$override_file" >/dev/null

  # Reload systemd daemon
  sudo systemctl daemon-reexec
}

#============================#
#        MAIN STAGES         #
#============================#
stage_pkgs() {
  safe_run "pre_network_fix" "Pre-network setup (nano + resolv.conf)"
  safe_run "check_internet" "Checking internet"
  safe_run "system_prep" "System update and mirror optimization"
  safe_run "install_pkgs \"\${CORE_PKGS[@]}\"" "Installing core packages"
  $EXTRAS && safe_run "install_pkgs \"\${EXTRA_PKGS[@]}\"" "Installing extra packages"
  $GAMING && safe_run "install_pkgs \"\${GAMING_PKGS[@]}\"" "Installing gaming packages"
  safe_run "install_aur \"\${AUR_PKGS[@]}\"" "Installing AUR packages"
}

stage_dotfiles() {
  safe_run "sync_dotfiles" "Syncing dotfiles"
  safe_run "set_fish_shell" "Configuring fish shell"
}

stage_services() {
  safe_run "setup_user_services" "Reloading user services"
  safe_run "setup_system_services" "Configuring system services"
  safe_run "setup_autologin" "Setting up autologin for current user"
}

#============================#
#        ENTRY POINT         #
#============================#
EXTRAS=false
GAMING=false
STAGE="all"

if [[ $EUID -eq 0 ]]; then
  error "Run as user, not root."
  exit 1
fi

sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT

while [[ $# -gt 0 ]]; do
  case $1 in
    --extras) EXTRAS=true ;;
    --gaming) GAMING=true ;;
    pkgs|dotfiles|services|all) STAGE=$1 ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

case $STAGE in
  pkgs)      stage_pkgs ;;
  dotfiles)  stage_dotfiles ;;
  services)  stage_services ;;
  all)       stage_pkgs; stage_dotfiles; stage_services ;;
esac

log "✅ Post-install stage [$STAGE] complete!"

if [[ $STAGE == "all" ]]; then
  if prompt "Reboot now to apply changes?"; then
    log "Rebooting…"
    sudo reboot
  else
    log "Reboot skipped. Please reboot manually later."
  fi
fi

