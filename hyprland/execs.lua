local vars = require("variables")
local fn   = require("utils.functions")

hl.on("hyprland.start", function()
    -- Start systemd session target & desktop portals for screen sharing
    hl.exec_cmd("dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal")

    -- Keyring and auth (NixOS-safe fallback)
    -- Guarded: these are optional, and an exec that always fails is noise in
    -- the log on every single login. gnome-keyring is not installed on this
    -- machine, so nothing was providing a secret store.
    hl.exec_cmd("command -v gnome-keyring-daemon >/dev/null && gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hyprpolkitagent || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || polkit-kde-authentication-agent-1")

    -- Wallpapers and launcher
    -- The first name in this chain, "aww", does not exist anywhere; the daemon
    -- is awww-daemon. Kept last as a fallback rather than first as a failure.
    hl.exec_cmd("awww-daemon || awww || aww")
    hl.exec_cmd("sleep 0.5 && (awww restore || aww restore)")
    hl.exec_cmd("command -v hyprlauncher >/dev/null && hyprlauncher -d")

    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Location provider and night light
    hl.exec_cmd("gammastep")

    -- Forward bluetooth media commands to MPRIS
    hl.exec_cmd("mpris-proxy")

    -- Start shell & super tap listener
    hl.exec_cmd("quickshell -d")
    -- super_tap.py is deliberately not started.
    --
    -- It is a second Super-tap detector: it reads /dev/input/event* directly and
    -- opens the launcher, while keybinds.lua already binds SUPER_L to
    -- super_launcher.sh press/release for exactly the same purpose. With both
    -- running a single tap fires twice -- open, then immediately close -- which
    -- looks like the launcher refusing to open.
    --
    -- It also accumulated: "pkill; start &" races with itself, and two copies
    -- were found running at once, each holding every input device open.
    --
    -- Re-enable this only if you also remove the SUPER_L binds in keybinds.lua.
    -- hl.exec_cmd("pkill -f super_tap.py; python3 ~/.config/hypr/hyprland/scripts/super_tap.py &")
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
