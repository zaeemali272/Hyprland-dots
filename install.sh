#!/usr/bin/env bash
# Install.sh – Arch post-install automation (Hyprland, Ironbar, etc.)
# Safe, idempotent, modular

set -euo pipefail

#============================#
#         CONFIG             #
#============================#
DOTS_DIR="$(pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

CORE_PKGS=(
  base base-devel git fish neovim wget curl unzip zip
  hyprland waybar ironbar kitty fuzzel
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol
  brightnessctl bluez bluez-utils networkmanager
  starship eza ripgrep fd jq
)

EXTRA_PKGS=( gparted htop ncdu rar unzip )

GAMING_PKGS=(
  steam lutris wine winetricks mangohud goverlay gamemode
)

WAYDROID_PKGS=( waydroid python-gbinder )

#============================#
#         HELPERS            #
#============================#
log()    { echo -e "\e[1;32m[INFO]\e[0m $*"; }
warn()   { echo -e "\e[1;33m[WARN]\e[0m $*"; }
error()  { echo -e "\e[1;31m[ERR ]\e[0m $*" >&2; }
prompt() { read -rp "[?] $1 [y/N]: " r; [[ $r =~ ^[Yy]$ ]]; }

#============================#
#      INSTALL PACKAGES      #
#============================#
install_pkgs() {
  local pkgs=("$@")
  sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"
}

#============================#
#        DOTFILES SYNC       #
#============================#
sync_dotfiles() {
  log "Syncing dotfiles…"
  rsync -avh --backup --suffix="$BACKUP_SUFFIX" \
    --exclude ".git" --exclude "README.md" \
    --exclude "Install.sh" \
    "$DOTS_DIR"/.config/ "$HOME/.config/"
}

#============================#
#     SHELL CONFIG           #
#============================#
set_fish_shell() {
  if ! grep -q "$(command -v fish)" /etc/shells; then
    log "Adding fish to /etc/shells"
    echo "$(command -v fish)" | sudo tee -a /etc/shells
  fi
  if [[ $SHELL != *fish ]]; then
    log "Changing default shell to fish"
    chsh -s "$(command -v fish)"
  fi
}

#============================#
#     SYSTEMD SERVICES       #
#============================#
setup_user_services() {
  log "Enabling user services (Ironbar etc)…"
  systemctl --user daemon-reload
  systemctl --user enable ironbar.service || true
}

setup_system_services() {
  log "Installing bluetooth-autofix system service…"
  if [[ -f "$DOTS_DIR/systemd/system/bluetooth-autofix.service" ]]; then
    sudo cp "$DOTS_DIR/systemd/system/bluetooth-autofix.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable bluetooth-autofix.service
  else
    warn "bluetooth-autofix.service not found in repo!"
  fi
}

#============================#
#        WAYDROID            #
#============================#
setup_waydroid() {
  install_pkgs "${WAYDROID_PKGS[@]}"
  if $WAYDROID_INIT; then
    log "Initializing Waydroid…"
    sudo waydroid init
  else
    warn "Skipping Waydroid init (pass --waydroid-init to auto-run)."
  fi
}

#============================#
#        MAIN LOGIC          #
#============================#
EXTRAS=false
GAMING=false
WAYDROID=false
WAYDROID_INIT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --extras) EXTRAS=true ;;
    --gaming) GAMING=true ;;
    --waydroid) WAYDROID=true ;;
    --waydroid-init) WAYDROID=true; WAYDROID_INIT=true ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

# Require non-root
if [[ $EUID -eq 0 ]]; then
  error "Run as user, not root."
  exit 1
fi

# Run tasks
install_pkgs "${CORE_PKGS[@]}"
$EXTRAS && install_pkgs "${EXTRA_PKGS[@]}"
$GAMING && install_pkgs "${GAMING_PKGS[@]}"
$WAYDROID && setup_waydroid

sync_dotfiles
set_fish_shell
setup_user_services
setup_system_services

log "✅ Post-install setup complete!"
