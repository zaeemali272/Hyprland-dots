local vars = require("variables")
local fn   = require("utils.functions")

hl.on("hyprland.start", function()
    -- Start systemd session target & desktop portals for screen sharing
    hl.exec_cmd("dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal")

    -- Keyring and auth (NixOS-safe fallback)
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hyprpolkitagent || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || polkit-kde-authentication-agent-1")

    -- Wallpapers and launcher
    hl.exec_cmd("aww || awww-daemon || awww")
    hl.exec_cmd("sleep 0.5 && (aww restore || awww restore)")
            
    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Location provider and night light
    hl.exec_cmd("gammastep")

    -- Forward bluetooth media commands to MPRIS
    hl.exec_cmd("mpris-proxy")

    -- Start shell & super tap listener
    hl.exec_cmd("quickshell -d")
    -- Super-tap listener.
    --
    -- Three things were wrong with "pkill -f super_tap.py; python3 ... &":
    --
    --   1. pkill -f matches the command line of the shell running this very
    --      command, because that line contains "super_tap.py". It could kill
    --      itself before python started. The [s]uper form is a regex that does
    --      not match the literal text of its own command line.
    --   2. ~ is not expanded by every shell in this position; $HOME always is.
    --   3. Nothing kept it alive if the launching shell went away.
    --
    -- It also needs read access to /dev/input/event*, which means membership of
    -- the "input" group. NixOS grants it in the system configuration; on Arch
    -- and most other distributions you have to:
    --
    --     sudo usermod -aG input $USER    # then log out and back in
    --
    -- Without it the process starts, cannot read a single device, and exits --
    -- so the Super tap silently does nothing while every other keybind works.
    hl.exec_cmd("pgrep -f '[s]uper_tap[.]py' >/dev/null 2>&1 || "
        .. "setsid python3 \"$HOME/.config/hypr/hyprland/scripts/super_tap.py\" "
        .. ">/dev/null 2>&1 &")
end)

-- Resizer listeners
local function apply_resizer_rules(win)
    local float_center = {
        hl.dsp.window.float({ action = "on", window = win }),
        hl.dsp.window.center({ window = win }),
    }
    local pip_actions = fn.move_actions(win) or {}

    -- Picture in picture
    fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, pip_actions, false)
end

hl.on("window.title", apply_resizer_rules)
hl.on("window.open", apply_resizer_rules)
