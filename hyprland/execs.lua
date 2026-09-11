local vars = require("variables")
local fn   = require("utils.functions")

-- Start `cmd` unless a process matching `pattern` (pgrep -f) already runs.
-- The NixOS config starts some of these as user services (hyprpolkitagent),
-- and a crashed-and-restarted compositor inherits the rest; without the
-- guard every login stacked a second copy of each daemon.
local function start_once(pattern, cmd)
    hl.exec_cmd("pgrep -f '" .. pattern .. "' >/dev/null 2>&1 || " .. cmd)
end

-- Runs once, when the compositor comes up. `hyprctl reload` does not re-run it.
hl.on("hyprland.start", function()
    -- Session environment, systemd target and desktop portals (screen sharing)
    hl.exec_cmd("dbus-update-activation-environment --all --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal")

    -- Keyring and auth
    hl.exec_cmd("command -v gnome-keyring-daemon >/dev/null && gnome-keyring-daemon --start --components=secrets")
    start_once("polkit-?(gnome|kde)?-?(agent|authentication)", "hyprpolkitagent || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || polkit-kde-authentication-agent-1")

    -- Wallpaper daemon. `awww query` succeeds only when a daemon already
    -- answers on the socket; starting a second one makes it abort with a Rust
    -- panic, which is what used to fill the shell log.
    hl.exec_cmd("awww query >/dev/null 2>&1 || awww-daemon")
    hl.exec_cmd("sleep 0.5 && awww restore")

    -- Clipboard: keep the last selection alive after its source window
    -- closes, and record history for the shell's clipboard panel.
    start_once("^wl-clip-persist", "wl-clip-persist --clipboard both")
    start_once("^wl-paste --type text", "wl-paste --type text --watch cliphist store")
    start_once("^wl-paste --type image", "wl-paste --type image --watch cliphist store")

    -- Night light
    start_once("^gammastep", "gammastep")

    -- Forward bluetooth media buttons to MPRIS
    start_once("^mpris-proxy", "mpris-proxy")

    hl.exec_cmd("hyprctl setcursor " .. vars.cursorTheme .. " " .. vars.cursorSize)

    -- Shell, then lock as soon as it is listening so a login never shows the
    -- desktop before a password. The lock screen is part of the shell, so it
    -- has to wait for the shell's global shortcuts to appear.
    start_once("^quickshell( |$)", "quickshell -d")
    -- hl.exec_cmd("for _ in $(seq 1 20); do sleep 0.5; hyprctl globalshortcuts 2>/dev/null | grep -q zenith:lock && ~/.config/quickshell/launch.sh lock && break; done")
end)

-- Picture-in-picture windows: float, shrink to a corner, keep aspect ratio
local function apply_resizer_rules(win)
    fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, fn.move_actions(win) or {}, false)
end

hl.on("window.title", apply_resizer_rules)
hl.on("window.open", apply_resizer_rules)
