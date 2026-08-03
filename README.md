# 🌌 Hyprland Configuration Environment

[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland%20Compositor-5865F2?style=for-the-badge&logo=hyprland&logoColor=white)](https://hyprland.org)
[![Nix Flake](https://img.shields.io/badge/Nix%20Flake-Supported-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](https://nixos.org)
[![Lua](https://img.shields.io/badge/Lua-5.1%20%2F%20LuaJIT-000080?style=for-the-badge&logo=lua&logoColor=white)](https://www.lua.org)
[![Home Manager](https://img.shields.io/badge/Home%20Manager-Module%20Included-3592C4?style=for-the-badge&logo=nixos&logoColor=white)](https://nix-community.github.io/home-manager/)

A modern, modular, Lua-driven **Hyprland** desktop configuration environment built for high performance on Wayland. It features dynamic Material You color palette generation, ergonomic window management, touchpad gesture control, special scratchpads with JSON app toggling, hardware OSD overlays, smooth bezier animations, and full **Nix Flake** / **Home Manager** integration.

---

## ✨ Features

- ⚡ **Lua-Driven Architecture**: Modular Lua engine (`hyprland.lua`, `variables.lua`, `hyprland/*.lua`) backed by standard `hyprland.conf` compatibility.
- 🎨 **Dynamic Material Color System**: Tailored theme palettes via `scheme/current.lua` and `scheme/default.lua` supporting HSL and Hex tokenization.
- 🏷️ **Intelligent Window & Layer Rules**: Automated window tagging system (`opaque`, `float`, `browser`, `terminal`, `projects`, `game`, `im`, `settings`, `music_player`, `system_monitor`) with auto-centering, smart opacities, and workspace pinning.
- 📱 **Special Workspaces & JSON App Toggles**: Dynamic scratchpad toggling driven by `hypr/cli.json` or `zenith/cli.json` for Discord, Spotify, Todolist, and System Monitors.
- ⌨️ **Ergonomic Keybindings**: Full set of keybindings for window tiling, floating, sizing, group tabs, workspaces, scratchpads, OSD, screenshots, recording, and app launching.
- 🤌 **Rich Touchpad Gestures**: Horizontal 4-finger workspace navigation, vertical 3-finger gesture volume and brightness control, 3-finger horizontal track skipping, and 3-finger pinch to play/pause.
- 🛠️ **Utility Integration**: Built-in shell script suite for screen recording (`wl-screenrec`), screenshot capture (`hyprshot`), OSD notifications (`osd.sh`), cursor zoom adjustment (`zoom.sh`), and OCR text extraction (`tesseract`).
- ❄️ **Nix Flake & Home Manager Ready**: Includes a top-level `flake.nix` providing a Home Manager module, developer shell (`nix develop`), and standard package outputs.

---

## 📂 Architecture & Directory Structure

```
~/.config/hypr/
├── flake.nix                 # Nix Flake providing Home Manager module, devShell, and package installer
├── hyprland.conf             # Bootstrap Hyprland config file (native rules, binds & fallbacks)
├── hyprland.lua              # Main Lua entrypoint initializing modules and path bindings
├── variables.lua             # Centralized settings, application defaults & keybinding map
├── hypr-vars.lua             # (Optional) User override file for personal settings
├── hyprlauncher.conf         # Configuration for Hyprlauncher app menu
├── hyprlock.conf             # Hyprlock screen locker styling & layout
├── hyprtoolkit.conf          # Hyprtoolkit styling parameters
│
├── hyprland/                 # Core Lua configuration modules
│   ├── animations.lua        # Custom bezier curves and window animation definitions
│   ├── decoration.lua        # Rounding, blur, xray, and shadow configurations
│   ├── env.lua               # System environment variables (Qt, GTK, Ozone, XDG)
│   ├── execs.lua            # System autostart daemons, keyrings & window listeners
│   ├── general.lua           # Layout parameters, dwindle engine, borders & gaps
│   ├── gestures.lua          # Multi-finger touchpad gestures and OSD handlers
│   ├── group.lua            # Tabbed window group styling and fonts
│   ├── input.lua            # Keyboard layout, repeat delay/rate, touchpad parameters
│   ├── keybinds.lua          # Keybinding event handlers & dispatcher bindings
│   ├── misc.lua             # Miscellaneous Hyprland engine settings & background color
│   ├── rules.lua            # Window tags, floating sizes, opacity rules, layer rules
│   └── scripts/             # Utility shell scripts
│       ├── fuzzel-emoji.sh   # Emoji selector script via fuzzel
│       ├── launch_first_available.sh # Helper script to launch first available binary
│       ├── osd.sh            # On-screen display for Volume & Brightness via notify-send
│       ├── record.sh         # Screen recording helper (region, window, sound, mic)
│       ├── restart_everything.sh # Daemon and shell restart script
│       ├── screenshot.sh     # Hyprshot screenshot helper with clipboard integration
│       └── zoom.sh           # Cursor zoom factor adjuster via hyprctl
│
├── scheme/                   # Color scheme definitions
│   ├── current.lua           # Active color scheme palette
│   └── default.lua           # Default fallback color scheme palette
│
└── utils/                    # Utility Lua modules
    ├── functions.lua         # Window placement, workspace helpers & config loaders
    └── json.lua              # Lightweight Lua JSON parser
```

---

## 🚀 Installation & Quick Start

### Option 1: Nix Flake & Home Manager (Recommended for NixOS)

Add this repository to your flake inputs and include the Home Manager module:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    hyprland-dots.url = "github:zaeemali272/Hyprland-dots";
  };

  outputs = { nixpkgs, home-manager, hyprland-dots, ... }: {
    homeConfigurations."user" = home-manager.lib.homeManagerConfiguration {
      modules = [
        hyprland-dots.homeManagerModules.default
        {
          programs.hyprland-dots.enable = true;
        }
      ];
    };
  };
}
```

### Option 2: Nix Run (Automated Installer)

If you have Nix installed with flakes enabled:

```bash
nix run github:zaeemali272/Hyprland-dots#install
```

### Option 3: Developer Shell (Nix)

To try out or test the workspace environment with all dependencies included:

```bash
nix develop
```

### Option 4: Manual Git Installation

Clone this repository into your `~/.config/hypr` directory:

```bash
# Backup existing Hyprland config if present
[ -d ~/.config/hypr ] && mv ~/.config/hypr ~/.config/hypr.bak

# Clone dotfiles
git clone https://github.com/zaeemali272/Hyprland-dots.git ~/.config/hypr
```

---

## ⌨️ Comprehensive Keybind Reference

### 🚀 Application Shortcuts
| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super` / `Super + D` | **App Launcher** | Toggle overview / app launcher (`fuzzel` / `rofi`) |
| `Super + Return` / `Super + T` | **Terminal** | Launch primary terminal (`kitty` / `ghostty`) |
| `Super + W` / `Super + B` | **Web Browser** | Launch web browser (`zen-beta` / `zen`) |
| `Super + E` | **File Manager** | Launch file explorer (`thunar` / `nemo`) |
| `Super + C` | **Code Editor** | Launch primary code editor (`antigravity-ide` / `codium`) |
| `Super + X` | **Text Editor** | Launch secondary editor (`zeditor` / `gnome-text-editor`) |
| `Ctrl + Alt + V` | **Audio Controls** | Open volume control GUI (`pavucontrol`) |
| `Ctrl + Shift + Esc` | **System Monitor** | Launch task manager (`missioncenter` / `btop`) |

---

### 🪟 Window Management
| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + Q` / `Super + Shift + Q` | **Close Window** | Close active window |
| `Super + Space` / `Super + Alt + Space` | **Toggle Float** | Toggle floating state for active window |
| `Super + F` | **Fullscreen** | Toggle full screen mode |
| `Super + Alt + F` | **Maximized** | Toggle bordered fullscreen (maximized) |
| `Super + P` | **Pin Window** | Pin floating window across all workspaces |
| `Super + Alt + \` | **Picture-in-Picture** | Scale and move active window to PiP corner |
| `Ctrl + Super + \` | **Center Window** | Center active window on screen |
| `Super + Arrow` / `Super + H/J/K/L` | **Focus Window** | Focus window in directional movement |
| `Super + Shift + Arrow` / `H/J/K/L` | **Move Window** | Move active window position |
| `Super + Ctrl + Arrow` / `H/J/K/L` | **Resize Window** | Resize active window dimensions |
| `Super + Alt + Arrow` / `H/J/K/L` | **Move Active** | Move floating window position |
| `Super + Left Mouse Drag` | **Move Window** | Drag window with mouse |
| `Super + Right Mouse Drag` | **Resize Window** | Resize window with mouse |

---

### 🖥️ Workspaces & Groups (Tabs)
| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + 1..9, 0` | **Switch Workspace** | Jump directly to workspace 1–10 |
| `Super + Shift + 1..9, 0` | **Move to Workspace** | Move window to workspace 1–10 silently |
| `Super + Mouse Scroll` | **Cycle Workspace** | Switch to previous / next workspace |
| `Ctrl + Super + Right / Left` | **Cycle Workspace** | Navigate workspace right or left |
| `Super + Alt + Page_Down / Up` | **Move Window WS** | Move window to next/prev workspace |
| `Alt + Tab` / `Shift + Alt + Tab` | **Cycle Windows** | Cycle focus to next / previous window |
| `Super + Comma (,)` | **Toggle Group** | Group active windows into tabbed container |
| `Super + Shift + Comma` | **Lock Group** | Lock active window group |
| `Super + U` | **Ungroup** | Remove window from active tab group |
| `Ctrl + Alt + Tab` | **Group Next Tab** | Cycle to next tab in active group |

---

### 📱 Special Scratchpads & App Toggles
| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + S` | **General Scratchpad** | Toggle special general scratchpad workspace |
| `Super + M` | **Music Scratchpad** | Toggle music player scratchpad (Spotify / Feishin) |
| `Super + D` | **Communication Scratchpad** | Toggle communication scratchpad (Discord / Vesktop) |
| `Super + R` | **To-Do Scratchpad** | Toggle task manager scratchpad (Todoist) |
| `Ctrl + Shift + Esc` | **System Monitor Scratchpad**| Toggle system monitor scratchpad (btop / missioncenter) |

---

### 🔊 Media, Volume & Brightness (OSD Integration)
| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `XF86AudioRaiseVolume` | **Volume Up** | Raise output volume with OSD notification |
| `XF86AudioLowerVolume` | **Volume Down** | Lower output volume with OSD notification |
| `XF86AudioMute` / `Super + Shift + M` | **Mute Audio** | Toggle audio output mute |
| `XF86AudioMicMute` | **Mute Mic** | Toggle microphone mute |
| `XF86MonBrightnessUp` | **Brightness Up** | Raise display brightness with OSD |
| `XF86MonBrightnessDown` | **Brightness Down** | Lower display brightness with OSD |
| `XF86AudioPlay` / `Ctrl + Super + Space` | **Play / Pause** | Toggle media playback |
| `XF86AudioNext` / `Ctrl + Super + Equal` | **Next Track** | Skip to next track |
| `XF86AudioPrev` / `Ctrl + Super + Minus` | **Prev Track** | Skip to previous track |

---

### 📷 Screenshots, Recording & Utilities
| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Print` | **Full Screenshot** | Capture active display output |
| `Super + Shift + S` / `Print Region` | **Area Screenshot** | Select region to capture via `hyprshot` |
| `Alt + Print` | **Window Screenshot** | Capture active window |
| `Super + Alt + R` | **Record Region** | Screen record selected region via `wl-screenrec` |
| `Ctrl + Alt + R` | **Record Display** | Fullscreen display recording with audio |
| `Super + Shift + ALT + R` | **Record All** | Fullscreen multi-monitor recording |
| `Super + Shift + C` | **Color Picker** | Inspect color code under cursor (`hyprpicker`) |
| `Super + V` | **Clipboard** | View clipboard history manager (`cliphist`) |
| `Super + Period (.)` | **Emoji Picker** | Open emoji selector menu (`fuzzel-emoji.sh`) |
| `Super + Shift + T` | **OCR Text Capture** | Grab text from screen region to clipboard via Tesseract |
| `Super + Equal (=)` | **Zoom In** | Zoom screen in under cursor (`zoom.sh`) |
| `Super + Minus (-)` | **Zoom Out** | Zoom screen out |

---

### ⚙️ System & Power Management
| Keybinding | Action | Description |
| :--- | :--- | :--- |
| `Super + L` / `Super + Escape` | **Lock Screen** | Lock display via `hyprlock` |
| `Alt + Escape` | **Reload Hyprland** | Trigger instant Hyprland configuration reload |
| `Ctrl + Super + R` | **Restart Shell** | Kill and restart Quickshell daemon & Hyprland (`restart_everything.sh`) |
| `Ctrl + Escape` | **Toggle Shell** | Toggle Quickshell visibility |
| `Ctrl + Alt + Delete` | **Power Menu** | Open session / shutdown menu |
| `Super + Shift + L` | **Suspend System** | Put machine to sleep (`systemctl suspend-then-hibernate`) |

---

## 🤌 Touchpad Gestures

| Gesture | Action |
| :--- | :--- |
| **4-Finger Horizontal Swipe** | Navigate between active workspaces |
| **3-Finger Vertical Swipe (Up / Down)** | Adjust output volume with OSD feedback |
| **3-Finger + CTRL Vertical Swipe (Up / Down)** | Adjust display brightness with OSD feedback |
| **3-Finger Horizontal Swipe (Left / Right)** | Skip to previous / next media track |
| **3-Finger Pinch** | Toggle media play/pause state |
| **4-Finger Swipe Up** | Toggle special scratchpad workspace |

---

## ⚙️ Customization & User Overrides

### 1. User Variables Override (`hypr-vars.lua`)
Create a file named `hypr-vars.lua` in `~/.config/hypr/`. Any settings declared in this file automatically override `variables.lua` without touching core code:

```lua
-- ~/.config/hypr/hypr-vars.lua
return {
    terminal       = "alacritty",
    browser        = "firefox",
    fileExplorer   = "nemo",
    windowRounding = 12,
    windowGapsIn   = 8,
    windowGapsOut  = 16,
}
```

### 2. Custom Color Schemes (`scheme/current.lua`)
You can adjust active colors in `scheme/current.lua` using HSL or Hex values. The palette tokens are loaded automatically into Hyprland border colors, active shadows, and window decorations.

### 3. Scratchpad Apps Config (`hypr/cli.json`)
App toggling for special scratchpads is dynamically configured via `~/.config/hypr/cli.json` (or `~/.config/zenith/cli.json`):

```json
{
  "toggles": {
    "communication": {
      "discord": {
        "enable": true,
        "match": [{ "class": "discord" }],
        "command": ["vesktop"],
        "move": true
      }
    },
    "music": {
      "spotify": {
        "enable": true,
        "match": [{ "class": "Spotify" }],
        "command": ["spotify"],
        "move": true
      }
    }
  }
}
```

---

## 🛠️ Utility Scripts Reference

| Script | Location | Purpose |
| :--- | :--- | :--- |
| `osd.sh` | `hyprland/scripts/osd.sh` | Controls volume & brightness via `wpctl` & `brightnessctl` with formatted OSD notifications. |
| `record.sh` | `hyprland/scripts/record.sh` | High-performance screen recorder supporting region selection, audio monitor loopback, and mic inputs. |
| `screenshot.sh` | `hyprland/scripts/screenshot.sh` | Quiet screenshot helper using `hyprshot`, auto-saving to `~/Pictures/Screenshots` & copying to clipboard. |
| `zoom.sh` | `hyprland/scripts/zoom.sh` | Dynamic cursor zoom level adjuster using `hyprctl` keywords and repl. |
| `restart_everything.sh` | `hyprland/scripts/restart_everything.sh` | Safely restarts user daemons (`quickshell`, `wireplumber`, `pipewire`) and reloads Hyprland. |
| `fuzzel-emoji.sh` | `hyprland/scripts/fuzzel-emoji.sh` | Standalone emoji launcher using `fuzzel` for instant searching and insertion. |
| `launch_first_available.sh` | `hyprland/scripts/launch_first_available.sh` | Checks binary availability in `$PATH` and launches the first available application fallback. |

---

## 📦 Required Dependencies Matrix

| Category | Component / Binary | Description |
| :--- | :--- | :--- |
| **Compositor** | `hyprland` | Wayland Compositor |
| **Locker & Picker** | `hyprlock`, `hyprpicker`, `hyprshot` | Lockscreen, color picker & screenshot tool |
| **Shell & Launcher** | `quickshell` / `zenith`, `fuzzel`, `rofi` | UI desktop shell and application launchers |
| **Audio & Media** | `wireplumber`, `wpctl`, `playerctl`, `pavucontrol` | Pipewire audio control and media player dispatcher |
| **Hardware** | `brightnessctl` | Screen backlight control |
| **Clipboard** | `wl-clipboard`, `cliphist`, `wl-clip-persist` | Persistent Wayland clipboard manager |
| **Recording & Capture**| `wl-screenrec`, `gpu-screen-recorder`, `grim`, `slurp`, `tesseract` | Screen recording, region selection & OCR engine |
| **Runtime & Scripting**| `luajit` / `lua`, `jq`, `libnotify` | Configuration engine and notification daemon |

---

## 📄 License

This configuration environment is open-source and released under the [MIT License](LICENSE).
