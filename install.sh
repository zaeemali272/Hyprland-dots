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
  hyprland kitty fuzzel
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber pavucontrol
  brightnessctl bluez bluez-utils iwd
  starship eza ripgrep fd jq
)

EXTRA_PKGS=( gparted htop ncdu rar unzip )

GAMING_PKGS=(
  steam lutris wine winetricks mangohud goverlay gamemode
)

AUR_PKGS=( ironbar-git )

#============================#
#         HELPERS            #
#============================#
log()    { echo -e "\e[1;32m[INFO]\e[0m $*"; }
warn()   { echo -e "\e[1;33m[WARN]\e[0m $*"; }
error()  { echo -e "\e[1;31m[ERR ]\e[0m $*" >&2; }
prompt() { read -rp "[?] $1 [y/N]: " r; [[ $r =~ ^[Yy]$ ]]; }

#============================#
#     CONNECTIVITY CHECK     #
#============================#
check_internet() {
  log "Checking internet connectivity…"
  if ! ping -c 1 archlinux.org &>/dev/null; then
    error "No internet connection detected. Please connect before running this script."
    exit 1
  fi
}

#============================#
#   SYSTEM UPDATE + MIRRORS  #
#============================#
system_prep() {
  log "Updating system package database…"
  sudo pacman -Syyu --noconfirm

  if ! pacman -Q reflector &>/dev/null; then
    log "Installing reflector for mirror optimization…"
    sudo pacman -S --needed --noconfirm reflector
  fi

  log "Optimizing mirrors with reflector…"
  sudo reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
}

#============================#
#   PACMAN & YAY INSTALLER   #
#============================#
install_pkgs() {
  local pkgs=("$@")
  sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"
}

ensure_yay() {
  if ! command -v yay &>/dev/null; then
    log "Installing yay (AUR helper)…"
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir"
    pushd "$tmpdir"
    makepkg -si --noconfirm
    popd
    rm -rf "$tmpdir"
  else
    log "yay already installed."
  fi
}

install_aur() {
  local pkgs=("$@")
  ensure_yay
  yay -Syu --needed --noconfirm "${pkgs[@]}"
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
  log "Configuring system services (iwd instead of NetworkManager)…"
  sudo systemctl disable --now NetworkManager.service || true
  sudo systemctl enable --now iwd.service

  if [[ -f "$DOTS_DIR/systemd/system/bluetooth-autofix.service" ]]; then
    sudo cp "$DOTS_DIR/systemd/system/bluetooth-autofix.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable bluetooth-autofix.service
  else
    warn "bluetooth-autofix.service not found in repo!"
  fi
}

#============================#
#        MAIN LOGIC          #
#============================#
EXTRAS=false
GAMING=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --extras) EXTRAS=true ;;
    --gaming) GAMING=true ;;
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
check_internet
system_prep
install_pkgs "${CORE_PKGS[@]}"
$EXTRAS && install_pkgs "${EXTRA_PKGS[@]}"
$GAMING && install_pkgs "${GAMING_PKGS[@]}"
install_aur "${AUR_PKGS[@]}"

sync_dotfiles
set_fish_shell
setup_user_services
setup_system_services

log "✅ Post-install setup complete!"

#============================#
#        REBOOT PROMPT       #
#============================#
if prompt "Reboot now to apply changes?"; then
  log "Rebooting…"
  sudo reboot
else
  log "Reboot skipped. Please reboot manually later."
fi

