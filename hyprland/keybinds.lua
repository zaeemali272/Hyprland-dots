local vars = require("variables")
local fn   = require("utils.functions")

-- Flags
local locked           = { locked = true }
local mouse            = { mouse = true }
local release          = { release = true }
local repeating        = { repeating = true }
local locked_repeating = { locked = true, repeating = true }

local function normalise_keybind(key)
    return key:gsub("%s+", ""):lower()
end

local function repeating_unless_mouse(key)
    return not normalise_keybind(key):find("mouse", 1, true) and repeating or nil
end

local function flatten_keybinds(keybinds, keys)
    keys = keys or {}

    if type(keybinds) == "table" then
        for _, keybind in ipairs(keybinds) do
            flatten_keybinds(keybind, keys)
        end
    elseif keybinds ~= nil then
        keys[#keys + 1] = keybinds
    end

    return keys
end

local function mark_combo_cmd()
    os.execute("~/.config/quickshell/scripts/super_launcher.sh mark_combo 2>/dev/null &")
end

local function create_bind(keybinds, action, flags)
    local get_flags = type(flags) == "function" and flags or function()
        return flags
    end

    for _, key in ipairs(flatten_keybinds(keybinds)) do
        local norm = normalise_keybind(key)
        local is_super_combo = norm:find("super", 1, true) and not (norm == "super_l" or norm == "super")

        if is_super_combo then
            if type(action) == "table" then
                if action.dispatcher == "exec" then
                    local new_action = {
                        dispatcher = "exec",
                        args = "~/.config/quickshell/scripts/super_launcher.sh mark_combo; " .. tostring(action.args or "")
                    }
                    hl.bind(key, new_action, get_flags(key))
                else
                    local target_action = action
                    hl.bind(key, function(...)
                        mark_combo_cmd()
                        return hl.dispatch(target_action)
                    end, get_flags(key))
                end
            elseif type(action) == "function" then
                local orig = action
                hl.bind(key, function(...)
                    mark_combo_cmd()
                    return orig(...)
                end, get_flags(key))
            else
                hl.bind(key, function(...)
                    mark_combo_cmd()
                    return hl.dispatch(action)
                end, get_flags(key))
            end
        else
            hl.bind(key, action, get_flags(key))
        end
    end
end

-- Launcher toggle (Opens on single SUPER_L release)
create_bind(vars.kbLock, hl.dsp.exec_cmd("$HOME/.config/hyprlock/scripts/hyprlock.sh"), locked)

-- Launcher
create_bind("SUPER_L", hl.dsp.exec_cmd("~/.config/quickshell/scripts/super_launcher.sh press"))
create_bind("SUPER_L", hl.dsp.exec_cmd("~/.config/quickshell/scripts/super_launcher.sh release"), release)
create_bind(vars.kbLauncher, hl.dsp.exec_cmd("~/.config/quickshell/launch.sh launcher || zenith launcher"))

-- Restore lock
create_bind(vars.kbRestoreLock, function()
    hl.dispatch(hl.dsp.exec_cmd("quickshell -d"))
end)

-- Kill/restart shell & hyprland cleanly
create_bind("CTRL + SUPER + R", hl.dsp.exec_cmd("pkill quickshell && quickshell -d && hyprctl reload || quickshell -d && hyprctl reload"), release)
create_bind("CTRL + ESCAPE", hl.dsp.exec_cmd("pkill quickshell || quickshell -d"), release)
create_bind("ALT + ESCAPE", hl.dsp.exec_cmd("hyprctl reload"), release)

-- Zenith-shell
create_bind("CTRL + SUPER + T", hl.dsp.exec_cmd("~/.config/quickshell/launch.sh wallpaper || zenith wallpaper"))
create_bind("SUPER + A", hl.dsp.exec_cmd("~/.config/quickshell/launch.sh dashboard || zenith dashboard"))
create_bind("SUPER + SHIFT + A", hl.dsp.exec_cmd("~/.config/quickshell/launch.sh ai || zenith ai"))
create_bind("CTRL + SUPER + A", hl.dsp.exec_cmd("~/.config/quickshell/launch.sh pomodoro || zenith pomodoro"))
create_bind("CTRL + SUPER + S", hl.dsp.exec_cmd("~/.config/quickshell/launch.sh volume || zenith volume"))
create_bind("CTRL + SUPER + C", hl.dsp.exec_cmd("~/.config/quickshell/launch.sh close || zenith close"))
create_bind("SUPER + V", hl.dsp.exec_cmd("~/.config/quickshell/launch.sh clipboard || zenith clipboard"))
create_bind("SUPER + PERIOD", hl.dsp.exec_cmd("~/.config/quickshell/launch.sh emoji || zenith emoji"))
create_bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd("~/.config/quickshell/launch.sh power || zenith power"))

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    create_bind(vars.kbGoToWs .. " + " .. key, fn.wsaction("focus", "", i))
    create_bind(vars.kbMoveWinToWs .. " + " .. key, fn.wsaction("move", "", i))
    create_bind(vars.kbGoToWsGroup .. " + " .. key, fn.wsaction("focus", "group", i))
    create_bind(vars.kbMoveWinToWsGroup .. " + " .. key, fn.wsaction("move", "group", i))
end

-- Go to workspace -1/+1
create_bind(vars.kbPrevWs, hl.dsp.focus({ workspace = "-1" }), repeating_unless_mouse)
create_bind(vars.kbNextWs, hl.dsp.focus({ workspace = "+1" }), repeating_unless_mouse)

-- Go to workspace group -1/+1
create_bind(vars.kbPrevWsGroup, hl.dsp.focus({ workspace = "-10" }), repeating_unless_mouse)
create_bind(vars.kbNextWsGroup, hl.dsp.focus({ workspace = "+10" }), repeating_unless_mouse)

-- Move window to workspace -1/+1
create_bind(vars.kbMoveWinToWsNext, hl.dsp.window.move({ workspace = "+1" }), repeating_unless_mouse)
create_bind(vars.kbMoveWinToWsPrev, hl.dsp.window.move({ workspace = "-1" }), repeating_unless_mouse)

-- Move window to/from special workspace
create_bind(vars.kbMoveWinToWsSpecial, hl.dsp.window.move({ workspace = "special:special" }))
create_bind(vars.kbMoveWinFromWsSpecial, hl.dsp.window.move({ workspace = "e+0" }))

-- Window groups
create_bind(vars.kbWindowCycleNext, hl.dsp.window.cycle_next(), repeating)
create_bind(vars.kbWindowCyclePrev, hl.dsp.window.cycle_next({ next = false }), repeating)
create_bind(vars.kbWindowGroupCycleNext, hl.dsp.group.next(), repeating)
create_bind(vars.kbWindowGroupCyclePrev, hl.dsp.group.prev(), repeating)
create_bind(vars.kbToggleGroup, hl.dsp.group.toggle())
create_bind(vars.kbUngroup, hl.dsp.window.move({ out_of_group = true }))
create_bind(vars.kbGroupLockActive, hl.dsp.group.lock_active())

-- Window actions
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    create_bind("SUPER + " .. dir, hl.dsp.focus({ direction = dir }))
    create_bind("SUPER + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end

create_bind(vars.kbWindowDecreaseWidth, fn.resize_active_window(-10, 0), repeating)
create_bind(vars.kbWindowIncreaseWidth, fn.resize_active_window(10, 0), repeating)
create_bind(vars.kbWindowDecreaseHeight, fn.resize_active_window(0, -10), repeating)
create_bind(vars.kbWindowIncreaseHeight, fn.resize_active_window(0, 10), repeating)

create_bind({ vars.kbMoveWindow, "SUPER + mouse:272" }, hl.dsp.window.drag(), mouse)
create_bind({ vars.kbResizeWindow, "SUPER + mouse:273" }, hl.dsp.window.resize(), mouse)
create_bind(vars.kbCenterWindow, hl.dsp.window.center())
create_bind(vars.kbNormalizeWindow, function()
    hl.dispatch(hl.dsp.window.resize(fn.resize_by_screen(55, 70)))
    hl.dispatch(hl.dsp.window.center())
end)
create_bind(vars.kbWindowPip, function()
    local a = hl.get_active_window()
    if a then
        local pip = fn.move_actions(a) or {}
        if not a.floating then table.insert(pip, 1, hl.dsp.window.float()) end
        table.insert(pip, hl.dsp.window.pin({ action = "on", window = "address:" .. a.address }))

        for _, x in ipairs(pip) do
            hl.dispatch(x)
        end
    end
end)
create_bind(vars.kbPinWindow, hl.dsp.window.pin())
create_bind(vars.kbWindowFullscreen, hl.dsp.window.fullscreen({ mode = "fullscreen" }))
create_bind(vars.kbWindowBorderedFullscreen, hl.dsp.window.fullscreen({ mode = "maximized" }))
create_bind(vars.kbToggleWindowFloating, hl.dsp.window.float())
create_bind(vars.kbCloseWindow, hl.dsp.window.close())
create_bind("SUPER + SHIFT + ALT + Q", hl.dsp.exec_cmd("hyprctl kill"))

-- Special workspace toggles
create_bind(vars.kbSpecialWs, fn.toggle("specialws"))
create_bind(vars.kbSystemMonitorWs, fn.toggle("sysmon"))
create_bind(vars.kbMusicWs, fn.toggle("music"))
create_bind(vars.kbCommunicationWs, fn.toggle("communication"))
create_bind(vars.kbTodoWs, fn.toggle("todo"))

-- Apps
create_bind({ vars.kbTerminal, "SUPER + Return", "ALT + Return" }, hl.dsp.exec_cmd(vars.terminal))
create_bind(vars.kbBrowser, hl.dsp.exec_cmd(vars.browser))
create_bind(vars.kbEditor, hl.dsp.exec_cmd(vars.editor))
create_bind(vars.kbFileExplorer, hl.dsp.exec_cmd(vars.fileExplorer))
create_bind(vars.kbAudioSettings, hl.dsp.exec_cmd(vars.audioSettings))
create_bind("SUPER + SHIFT + X", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/launch_first_available.sh 'zeditor' 'gnome-text-editor'"))
create_bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/launch_first_available.sh 'missioncenter' 'btop'"))

-- Utilities
create_bind(vars.kbScreenshot, hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/screenshot.sh output"), locked)
create_bind({ vars.kbScreenshotRegion, "SUPER + SHIFT + S" }, hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/screenshot.sh region"), locked)
create_bind("ALT + Print", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/screenshot.sh window"))

-- Screen Recording Keybinds (Zenith Script)
create_bind("SUPER + ALT + R", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/record.sh"))
create_bind("CTRL + ALT + R", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/record.sh --fullscreen"))
create_bind("SUPER + SHIFT + ALT + R", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/record.sh --fullscreen-all"))
create_bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/record.sh --fullscreen-sound"))

create_bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("grim -g \"$(slurp $SLURP_ARGS)\" \"tmp.png\" && tesseract \"tmp.png\" - | wl-copy && rm \"tmp.png\""))
create_bind(vars.kbColorPicker, hl.dsp.exec_cmd("hyprpicker -a"))

-- Brightness (OSD Integration)
create_bind("XF86MonBrightnessUp" , hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/osd.sh brightness up"), locked)
create_bind("XF86MonBrightnessDown" , hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/osd.sh brightness down"), locked)

-- Media
create_bind({ vars.kbMediaToggle, "XF86AudioPlay", "XF86AudioPause" }, hl.dsp.exec_cmd("playerctl play-pause"), locked)
create_bind({ vars.kbMediaNext, "XF86AudioNext" }, hl.dsp.exec_cmd("playerctl next"), locked)
create_bind({ vars.kbMediaPrev, "XF86AudioPrev" }, hl.dsp.exec_cmd("playerctl previous"), locked)
create_bind({ vars.kbMediaStop, "XF86AudioStop" }, hl.dsp.exec_cmd("playerctl stop"), locked)

-- Explicit mappings for legacy CD keycodes sent by earbuds
-- Expanded media bindings for stubborn earbuds
create_bind({ "XF86AudioPlay", "XF86AudioPause", "code:200", "code:201" }, hl.dsp.exec_cmd("playerctl play-pause"), locked)
create_bind({ "code:163", "XF86AudioNext" }, hl.dsp.exec_cmd("playerctl next"), locked)
create_bind({ "code:165", "XF86AudioPrev" }, hl.dsp.exec_cmd("playerctl previous"), locked)

-- Zoom controls
create_bind("SUPER + MINUS", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/zoom.sh decrease 0.1"), repeating)
create_bind("SUPER + EQUAL", hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/zoom.sh increase 0.1"), repeating)

-- Volume (OSD Integration)
create_bind({ vars.kbVolumeMute, "XF86AudioMute" }, hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/osd.sh volume mute"), locked)
create_bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), locked)
create_bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/osd.sh volume up"),
    locked_repeating
)
create_bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("~/.config/hypr/hyprland/scripts/osd.sh volume down"),
    locked_repeating
)

-- Sleep
create_bind({ vars.kbSleep, "SUPER + SHIFT + L" }, hl.dsp.exec_cmd("systemctl suspend"), locked)
create_bind("XF86PowerOff", hl.dsp.exec_cmd("~/.config/quickshell/launch.sh cmd quicksettings:power"))
create_bind("SUPER + XF86PowerOff", hl.dsp.exec_cmd("systemctl poweroff"), locked)

-- Clipboard and emoji picker
create_bind({ vars.kbClipboard, "SUPER + V" }, hl.dsp.exec_cmd("pkill fuzzel || anyrun --plugins libclipboard.so"))
create_bind({ vars.kbEmoji, "SUPER + PERIOD" }, hl.dsp.exec_cmd("pkill fuzzel || ~/.config/hypr/hyprland/scripts/fuzzel-emoji.sh copy"))

-- Testing Notifications
create_bind(
    "SUPER + ALT + F12",
    hl.dsp.exec_cmd(
        "notify-send -u low -i dialog-information-symbolic 'Test notification' " ..
        [["Here's a really long message to test truncation and wrapping\nYou can middle click or flick this notification to dismiss it!"]] ..
        " -a 'Shell' -A 'Test1=I got it!' -A 'Test2=Another action'"
    )
)
