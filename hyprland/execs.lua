local vars = require("variables")
local fn   = require("utils.functions")

hl.on("hyprland.start", function()
    -- Keyring and auth (NixOS-safe fallback)
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hyprpolkitagent || /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || polkit-kde-authentication-agent-1")

    -- Wallpapers and launcher
    hl.exec_cmd("aww || awww-daemon || awww")
    hl.exec_cmd("sleep 0.5 && (aww restore || awww restore)")
    hl.exec_cmd("hyprlauncher -d")

    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Location provider and night light
    hl.exec_cmd("gammastep")

    -- Forward bluetooth media commands to MPRIS
    hl.exec_cmd("mpris-proxy")

    -- Start shell
    hl.exec_cmd("quickshell -d")
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
