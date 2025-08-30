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
#      SAFE EXECUTION        #
#============================#
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
  safe_run "sudo pacman -Syyu --noconfirm" "Updating system package database"
  if ! pacman -Q reflector &>/dev/null; then
    safe_run "sudo pacman -S --needed --noconfirm reflector" "Installing reflector"
  fi
  safe_run "sudo reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist" "Optimizing mirrors with reflector"
}

#============================#
#   PACMAN & YAY INSTALLER   #
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

install_aur() {
  local pkgs=("$@")
  ensure_yay
  safe_run "yay -Syu --needed --noconfirm \"\${pkgs[@]}\"" "Installing AUR packages: ${pkgs[*]}"
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
  # Disable NetworkManager safely
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

  wifi_iface=$(ip -o link show | awk -F': ' '/wl/{print $2}' | head -n1)
  if [[ -n "$wifi_iface" ]]; then
    safe_run "sudo systemctl enable --now iwd.service" "Enabling iwd.service for interface $wifi_iface"
  else
    warn "⚠️ No Wi-Fi interface detected; skipping iwd.service start"
  fi

  if [[ -f "$DOTS_DIR/systemd/system/bluetooth-autofix.service" ]]; then
    safe_run "sudo cp \"$DOTS_DIR/systemd/system/bluetooth-autofix.service\" /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable bluetooth-autofix.service" "Installing bluetooth-autofix.service"
  else
    warn "bluetooth-autofix.service not found in repo!"
  fi
}

#============================#
#        MAIN STAGES         #
#============================#
stage_pkgs() {
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

