#!/usr/bin/env bash
# install.sh — Arch Linux Hyprland post-install (idempotent, safe backups)
# Zaeem edition: pacman + AUR split, rsync with backups by default, optional flags
# Usage examples:
#   ./install.sh                       # normal run: installs pkgs, copies dotfiles w/ backups
#   ./install.sh --no-overwrite        # only copy files that don't exist; never overwrite
#   ./install.sh --force               # overwrite without backups (not recommended)
#   ./install.sh --dry-run             # show what would change (no writes)
#   ./install.sh --skip-aur            # skip AUR bootstrap & packages
#   ./install.sh --no-icons            # skip OneUI icon theme step
#   ./install.sh --enable-user-services  # enable created *user* services after creation
#   ./install.sh -y                    # non-interactive (skips prompts like autologin)

set -Eeuo pipefail

###-------------------------------
### 0) Flags / Config
###-------------------------------
FORCE=false
DRY_RUN=false
NO_OVERWRITE=false
SKIP_AUR=false
NO_ICONS=false
NON_INTERACTIVE=false
ENABLE_USER_SERVICES=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --dry-run) DRY_RUN=true ;;
    --no-overwrite) NO_OVERWRITE=true ;;
    --skip-aur) SKIP_AUR=true ;;
    --no-icons) NO_ICONS=true ;;
    --enable-user-services) ENABLE_USER_SERVICES=true ;;
    -y|--yes|--non-interactive) NON_INTERACTIVE=true ;;
    *) echo "Unknown flag: $arg"; exit 2 ;;
  esac
done

DOTS_DIR="$(pwd)"             # expect script to run from repo root
BACKUP_SUFFIX=".bak-$(date +%Y%m%d-%H%M%S)"

# rsync options (always archive+verbose+human). Add progress when not dry-run.
RSYNC_OPTS=(-a -v -h)
if [[ "$DRY_RUN" == true ]]; then
  RSYNC_OPTS+=(--dry-run --progress)
else
  RSYNC_OPTS+=(--progress)
fi
# Overwrite policy
if [[ "$FORCE" == true ]]; then
  : # no backup, full overwrite
elif [[ "$NO_OVERWRITE" == true ]]; then
  RSYNC_OPTS+=(--ignore-existing)
else
  RSYNC_OPTS+=(--backup --suffix="$BACKUP_SUFFIX")
fi

###-------------------------------
### 1) Pre-check: Prevent root execution
###-------------------------------
if [[ "$EUID" -eq 0 ]]; then
  echo "❌ Please run this script as a regular user (not root)."
  exit 1
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }
log() { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m==>\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m!!\033[0m %s\n" "$*" >&2; }

###-------------------------------
### 2) Package lists (split: pacman vs AUR)
###-------------------------------
PACMAN_PKGS=(
  archlinux-keyring # keep fresh
  base base-devel linux linux-headers linux-firmware
  networkmanager nano fish git man-db efibootmgr intel-ucode cpupower
  pipewire pipewire-alsa pipewire-jack pipewire-pulse libpulse alsa-plugins pavucontrol easyeffects cava ffmpegthumbnailer
  hyprland hypridle hyprpicker hyprshot wl-clipboard slurp grim fuzzel wlogout mako swww
  qt5-wayland qt5ct qt6ct gtk3-demos qt5-tools qt6-tools xdg-desktop-portal xdg-desktop-portal-hyprland polkit-gnome wireplumber
  kvantum bibata-cursor-theme materia-gtk-theme adwaita-dark papirus-icon-theme noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-dejavu
  bluez bluez-utils bluez-tools nemo nemo-fileroller gnome-keyring gnome-text-editor
  glances playerctl tree jq eza starship yazi yt-dlp tumbler wget sshfs gammastep gamemode blueman kdeconnect speedtest-cli
  lutris wine winetricks gparted ncdu wev rar rfkill rsync
)

AUR_PKGS=(
  yay-bin          # bootstrap AUR helper via binary package for speed
  yay-debug        # optional
  visual-studio-code-bin youtube-music-bin zen-browser-bin
  ttf-material-icons-git ttf-material-symbols-variable-git ttf-nerd-fonts-symbols
  losslesscut-bin cloudflare-warp-bin python-pywal16 freedownloadmanager cameractrls
  illogical-impulse-oneui4-icons-git  # OneUI4 Icons via AUR (preferred over manual clone)
)

###-------------------------------
### 3) Package installation helpers
###-------------------------------
install_pacman_pkgs() {
  log "[1/5] Syncing keyring & installing pacman packages…"
  sudo pacman -Sy --noconfirm archlinux-keyring
  sudo pacman -S --noconfirm --needed "${PACMAN_PKGS[@]}"
}

bootstrap_yay() {
  if need_cmd yay; then return 0; fi
  $SKIP_AUR && { warn "Skipping AUR bootstrap (--skip-aur)."; return 0; }
  log "Bootstrapping yay (AUR helper)…"
  sudo pacman -S --noconfirm --needed base-devel git
  tmpdir="$(mktemp -d)"
  pushd "$tmpdir" >/dev/null
  git clone https://aur.archlinux.org/yay-bin.git
  ( cd yay-bin && makepkg -si --noconfirm )
  popd >/dev/null
  rm -rf "$tmpdir"
}

install_aur_pkgs() {
  $SKIP_AUR && { warn "Skipping AUR packages (--skip-aur)."; return 0; }
  need_cmd yay || bootstrap_yay
  if need_cmd yay; then
    log "[2/5] Installing AUR packages via yay…"
    yay -S --needed --noconfirm "${AUR_PKGS[@]}"
  else
    warn "yay not available; skipping AUR packages."
  fi
}

###-------------------------------
### 4) Deploy dotfiles (rsync with backups by default)
###-------------------------------
deploy_dotfiles() {
  log "[3/5] Deploying dotfiles to ~/.config and ~/.local (rsync)…"
  mkdir -p "$HOME/.config" "$HOME/.local"
  # Copy contents of repo folders into HOME folders
  rsync "${RSYNC_OPTS[@]}" "$DOTS_DIR/.config/" "$HOME/.config/"
  rsync "${RSYNC_OPTS[@]}" "$DOTS_DIR/.local/"  "$HOME/.local/"

  # Make scripts executable (best-effort)
  find "$HOME/.local/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
  find "$HOME/.config" -path '*/scripts/*' -type f -exec chmod +x {} \; 2>/dev/null || true

  if [[ "$DRY_RUN" == false && "$FORCE" == false && "$NO_OVERWRITE" == false ]]; then
    warn "Backups created with suffix: $BACKUP_SUFFIX (if overwrites occurred)."
  fi
}

###-------------------------------
### 5) Optional: Create user systemd services via heredoc
###-------------------------------
create_user_service() {
  local name="$1"; shift
  local content="$*"
  local unit_dir="$HOME/.config/systemd/user"
  mkdir -p "$unit_dir"
  printf "%s\n" "$content" >"$unit_dir/$name"
}

setup_user_services() {
  log "[4/5] Creating user services (if related scripts exist)…"

  # Example: bluetooth-autofix.service (only if script exists)
  if [[ -x "$HOME/.local/bin/bluetooth-autofix.sh" ]]; then
    create_user_service "bluetooth-autofix.service" "[Unit]
Description=Fix Bluetooth on boot and resume
After=bluetooth.target suspend.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/bluetooth-autofix.sh
RemainAfterExit=true

[Install]
WantedBy=default.target"
  fi

  systemctl --user daemon-reload || true
  if [[ "$ENABLE_USER_SERVICES" == true ]]; then
    need_cmd systemctl && systemctl --user enable --now bluetooth-autofix.service 2>/dev/null || true
  fi
}

###-------------------------------
### 5b) Install system-level services
###-------------------------------
install_system_services() {
  if [[ -d "$DOTS_DIR/systemd/system" ]]; then
    log "[4b/5] Installing system services (requires sudo)…"
    sudo cp "$DOTS_DIR"/systemd/system/*.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable bluetooth-autofix.service bluetooth-fix-after-lock.service || true
  else
    warn "No system services found in $DOTS_DIR/systemd/system/"
  fi
}

###-------------------------------
### 5c) Install helper scripts (system-wide)
###-------------------------------
install_scripts() {
  if [[ -d "$DOTS_DIR/scripts" ]]; then
    log "[4c/5] Installing helper scripts…"
    for script in "$DOTS_DIR"/scripts/*; do
      sudo install -Dm755 "$script" /usr/local/bin/$(basename "$script")
    done
  else
    warn "No scripts found in $DOTS_DIR/scripts/"
  fi
}

###-------------------------------
### 6) Optional: Icon theme (AUR preferred; fallback to manual clone)
###-------------------------------
install_icons() {
  [[ "$NO_ICONS" == true ]] && { warn "Skipping icon installation (--no-icons)."; return 0; }

  if need_cmd yay; then
    log "Installing OneUI4 icon theme via AUR (illogical-impulse-oneui4-icons-git)…"
    yay -S --needed --noconfirm illogical-impulse-oneui4-icons-git || true
  else
    log "AUR helper not available; falling back to manual clone…"
    tmpdir="$(mktemp -d)"
    git clone https://github.com/mjkim0727/OneUI4-Icons.git "$tmpdir/OneUI4-Icons"
    mkdir -p "$HOME/.icons"
    mv "$tmpdir/OneUI4-Icons/OneUI-dark" "$HOME/.icons/" || true
    rm -rf "$tmpdir"
  fi

  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface icon-theme "One UI Icon Theme" || true
    log "Icon theme applied via gsettings (if supported by your DE)."
  else
    warn "gsettings not found; set icon theme via lxappearance/qt6ct if needed."
  fi
}

###-------------------------------
### 7) Set fish as default shell (no root required)
###-------------------------------
set_fish_shell() {
  if ! echo "$SHELL" | grep -q fish; then
    log "Setting fish as default shell for $USER…"
    chsh -s /usr/bin/fish || warn "Failed to set shell. You can run: chsh -s /usr/bin/fish"
  fi
}

###-------------------------------
### 8) Optional: Autologin on tty1 (interactive by default)
###-------------------------------
setup_autologin() {
  if [[ "$NON_INTERACTIVE" == true ]]; then
    warn "Non-interactive mode: skipping autologin prompt."
    return 0
  fi
  read -rp "❓ Do you want to enable autologin on tty1? [y/N]: " enable_autologin
  if [[ "$enable_autologin" =~ ^[Yy]$ ]]; then
    local user_choice
    read -rp "🔍 Use current user '$USER'? [Y/n]: " user_choice
    local AUTOLOGIN_USER
    if [[ "$user_choice" =~ ^[Nn]$ ]]; then
      read -rp "👤 Enter username for autologin: " AUTOLOGIN_USER
    else
      AUTOLOGIN_USER="$USER"
    fi
    log "Configuring autologin for: $AUTOLOGIN_USER"
    local TTY_SERVICE="/etc/systemd/system/getty@tty1.service.d"
    sudo mkdir -p "$TTY_SERVICE"
    sudo tee "$TTY_SERVICE/override.conf" >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $AUTOLOGIN_USER --noclear %I \$TERM
EOF
    log "Autologin configured for '$AUTOLOGIN_USER' on tty1."
  else
    log "Skipping autologin setup."
  fi
}

###-------------------------------
### 9) rfkill status helper
###-------------------------------
rfkill_hint() {
  log "[5/5] Checking wireless/Bluetooth block status (rfkill)…"
  if ! need_cmd rfkill; then
    log "Installing rfkill…"
    sudo pacman -S --noconfirm rfkill || true
  fi
  rfkill list 2>/dev/null | grep -iE "bluetooth|wlan|wifi" || warn "rfkill output not found."
  echo "ℹ️  If any device is 'Soft blocked: yes', run: sudo rfkill unblock all"
}

###-------------------------------
### Main
###-------------------------------
log "Starting Hyprland post-install (idempotent, backups: ${BACKUP_SUFFIX})"
install_pacman_pkgs
install_aur_pkgs

deploy_dotfiles
setup_user_services
install_system_services
install_scripts
install_icons
set_fish_shell
setup_autologin
rfkill_hint

log "🎉 Setup complete. Reboot into Hyprland when ready."
if [[ "$DRY_RUN" == true ]]; then
  warn "This was a dry run — no changes were made."
fi

