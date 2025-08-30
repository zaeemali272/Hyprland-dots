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
  brightnessctl bluez bluez-utils iwd
  starship eza ripgrep fd jq
)

EXTRA_PKGS=( ncdu rar unzip )
GAMING_PKGS=( steam lutris wine winetricks mangohud goverlay gamemode )
AUR_PKGS=( ironbar-git kvantum kvantum-qt5 kvantum-theme-materia materia-gtk-theme )

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
  log "🔍 Checking internet connectivity…"
  if ! ping -c 1 archlinux.org &>/dev/null; then
    error "No internet connection detected. Please connect before running this script."
    exit 1
  fi
}

#============================#
#   SYSTEM UPDATE + MIRRORS  #
#============================#
system_prep() {
  log "📦 Updating system package database…"
  sudo pacman -Syyu --noconfirm

  if ! pacman -Q reflector &>/dev/null; then
    log "⬇️ Installing reflector for mirror optimization…"
    sudo pacman -S --needed --noconfirm reflector
  fi

  log "🌐 Optimizing mirrors with reflector (this may take a while)…"
  sudo reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist
}

#============================#
#   PACMAN & YAY INSTALLER   #
#============================#
install_pkgs() {
  local pkgs=("$@")
  log "📦 Installing packages: ${pkgs[*]}"
  sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"
}

ensure_yay() {
  if ! command -v yay &>/dev/null; then
    log "⬇️ Installing yay (AUR helper)…"
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir"
    pushd "$tmpdir"
    makepkg -si --noconfirm
    popd
    rm -rf "$tmpdir"
  else
    log "👍 yay already installed."
  fi
}

install_aur() {
  local pkgs=("$@")
  log "📦 Installing AUR packages: ${pkgs[*]}"
  ensure_yay
  yay -Syu --needed --noconfirm "${pkgs[@]}"
}

#============================#
#        DOTFILES SYNC       #
#============================#
sync_dotfiles() {
  log "🗂️ Syncing dotfiles into ~/.config …"
  rsync -avh --backup --suffix="$BACKUP_SUFFIX" \
    --exclude ".git" --exclude "README.md" \
    --exclude "Install.sh" \
    "$DOTS_DIR"/.config/ "$HOME/.config/"

  if [[ -d "$DOTS_DIR/.icons" ]]; then
    log "🎨 Syncing icons into ~/.icons …"
    rsync -avh --backup --suffix="$BACKUP_SUFFIX" \
      "$DOTS_DIR"/.icons/ "$HOME/.icons/"

    # --- unzip any archives in ~/.icons ---
    shopt -s nullglob
    for zipfile in "$HOME/.icons"/*.zip; do
      log "📦 Extracting icon archive: $(basename "$zipfile")"
      unzip -o "$zipfile" -d "$HOME/.icons/"
      rm -f "$zipfile"
    done
    shopt -u nullglob
  fi

  if [[ -d "$DOTS_DIR/.local" ]]; then
    log "📂 Syncing local files into ~/.local …"
    rsync -avh --backup --suffix="$BACKUP_SUFFIX" \
      "$DOTS_DIR"/.local/ "$HOME/.local/"
  fi
}

#============================#
#     SHELL CONFIG           #
#============================#
set_fish_shell() {
  log "🐟 Configuring fish shell…"
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
  log "⚙️ Reloading user systemd daemon…"
  systemctl --user daemon-reload
}

setup_system_services() {
  log "⚙️ Configuring system services…"

  # Disable NetworkManager safely
  if systemctl is-active --quiet NetworkManager.service; then
    log "🛑 Disabling NetworkManager.service"
    sudo systemctl disable --now NetworkManager.service || true
  else
    log "ℹ️ NetworkManager not active, skipping disable"
  fi

  # Create minimal iwd config if missing
  IWD_CONF_DIR="/etc/iwd"
  IWD_CONF_FILE="$IWD_CONF_DIR/main.conf"
  if [[ ! -d "$IWD_CONF_DIR" ]]; then
    log "📁 Creating iwd config directory $IWD_CONF_DIR"
    sudo mkdir -p "$IWD_CONF_DIR"
  fi
  if [[ ! -f "$IWD_CONF_FILE" ]]; then
    log "📝 Creating minimal iwd config at $IWD_CONF_FILE"
    echo -e "[General]\nEnableNetworkConfiguration=true" | sudo tee "$IWD_CONF_FILE" >/dev/null
  fi

  # Only enable iwd if a Wi-Fi interface exists
  wifi_iface=$(ip -o link show | awk -F': ' '/wl/{print $2}' | head -n1)
  if [[ -n "$wifi_iface" ]]; then
    log "📶 Enabling iwd.service for interface $wifi_iface"
    sudo systemctl enable --now iwd.service
  else
    warn "⚠️ No Wi-Fi interface detected; skipping iwd.service start"
  fi

  # Install bluetooth-autofix service if it exists
  if [[ -f "$DOTS_DIR/systemd/system/bluetooth-autofix.service" ]]; then
    log "🔧 Installing bluetooth-autofix.service"
    sudo cp "$DOTS_DIR/systemd/system/bluetooth-autofix.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable bluetooth-autofix.service
  else
    warn "bluetooth-autofix.service not found in repo!"
  fi
}

#============================#
#        MAIN STAGES         #
#============================#
stage_pkgs() {
  check_internet
  system_prep
  install_pkgs "${CORE_PKGS[@]}"
  $EXTRAS && install_pkgs "${EXTRA_PKGS[@]}"
  $GAMING && install_pkgs "${GAMING_PKGS[@]}"
  install_aur "${AUR_PKGS[@]}"
}

stage_dotfiles() {
  sync_dotfiles
  set_fish_shell
}

stage_services() {
  setup_user_services
  setup_system_services
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

# --- 🔑 Keep sudo alive across the whole script ---
sudo -v
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &
trap 'kill $(jobs -p) 2>/dev/null || true' EXIT
# -----------------------------------------------

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

