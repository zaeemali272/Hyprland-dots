# 🌐 Hyprland Arch Setup - Automated Dotfiles & Environment

####  A fully automated script to install, configure, and personalize your Arch Linux with Hyprland and a minimal Wayland-only desktop.
#### This setup includes your custom dotfiles, essential utilities, UI themes, and personal preferences — with interactive choices for gaming setup and Waydroid.

## 🎥 Quick Overview
<p align="center">
  <a href="https://youtu.be/KwMltR92CV0">▶️ Watch Overview Video</a>
</p>

### 📸 Screenshots

<details> <summary>✨ New Desktop Setup</summary> <p align="center"> <img src=".assets/new_desktop_1.png" width="700"><br> <img src=".assets/new_desktop_2.png" width="700"> </p> </details> <details> <summary>🖼️ Old Desktop Setup (Before Migration)</summary> <p align="center"> <img src=".assets/old_desktop_1.png" width="700"><br> <img src=".assets/old_desktop_2.png" width="700"><br> <img src=".assets/old_desktop_3.png" width="700"> </p> </details> <details> <summary>🧩 Ironbar UI Preview (New vs Old)</summary> <p align="center"> <img src=".assets/new_ironbar.png" width="700"><br> <img src=".assets/old_ironbar.png" width="700"> </p> </details> <details> <summary>🔔 Mako Notification Style</summary> <p align="center"> <img src=".assets/mako.png" width="700"> </p> </details>
</br>


## 📦 What's Included?   
🔹 Fully scripted Arch install (no manual package entry)  
🔹 Wayland desktop with Hyprland  
🔹 Notifications via Mako.  
🔹 Status bar = Ironbar.   
🔹 Menus/launcher = Fuzzel.    
🔹 Audio stack = PipeWire + EasyEffects.

## 🗂️ Repo Structure
Hyprland-dots/  
├── .config/           → All configs (Hyprland, Ironbar, Fuzzel, Fish, etc.)  
├── .local/            → Local scripts, fish history, color schemes   
├── systemd/system/    → Custom system services (e.g. Bluetooth fixes)    
├── scripts/           → Helper scripts (installed to /usr/local/bin/)    
├── .assets/           → Screenshots + overview video   
├── install.sh         → Main install and setup script    
└── README.md          → You're here


## 📥 Installation
### 1. Boot into Arch with internet (TTY)

This script is intended for a fresh Arch Linux minimal install.

### 2. Clone the repo

```
git clone https://github.com/zaeemali272/Hyprland-dots.git                 
cd Hyprland-dots
```

### 3. Run the installer

```
chmod +x install.sh
./install.sh
```

The script is idempotent — safe to re-run, will back up existing configs unless --force is used.

<br>

## ⚡ Installer Flags  

You can control behavior with flags:  

| Flag                   | Description                                       |
|------------------------|---------------------------------------------------|
| `--dry-run`            | Show what would change (no writes)                |
| `--force`              | Overwrite without backups (**dangerous**)         |
| `--no-overwrite`       | Skip overwriting existing files                   |
| `--skip-aur`           | Skip AUR bootstrap & packages                     |
| `--no-icons`           | Skip OneUI icon theme step                        |
| `--enable-user-services` | Enable created user services after creation    |
| `-y` or `--non-interactive` | Run without prompts (default **yes** to optional steps) |



## 🎮 Gaming Setup (Optional)

When prompted, you can install the gaming stack:

- **Lutris**  
- **Wine + Winetricks**  
- **Gamemode**  
- **Steam** (if you add it to `PACMAN_PKGS`)  
- **Game-related optimizations**  

If you say **no**, the related scripts/services are removed so your environment stays clean.


## 📱 Waydroid Setup (Optional)

The installer will ask if you want Waydroid:

- If yes → installs Waydroid + helper scripts + systemd user services.
- If no → asks if you want to keep the scripts (for later manual setup) or purge them completely.


## 🔐 Autologin

The script can optionally set up autologin on **tty1** with:

```
/etc/systemd/system/getty@tty1.service.d/override.conf
```

It then starts Hyprland automatically via `config.fish`.


## ✅ Final Checks

Before finishing, the script runs:

- rfkill list → warns if Wi-Fi or Bluetooth are blocked.
- Ensures services are reloaded.
- Prints reboot recommendation.


## 🚀 After Installation

- Log in → you’ll land directly in Hyprland.
- Wallpapers managed with swww.
- Notifications via Mako.
- Status bar = Ironbar.
- Menus/launcher = Fuzzel.
- Audio stack = PipeWire + EasyEffects.
