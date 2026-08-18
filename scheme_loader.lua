-- Resolves the colour scheme once, for every consumer.
--
-- scheme/current.lua is generated from the wallpaper at runtime and is
-- gitignored, so it does not exist on a fresh clone, and hyprland.lua's
-- maybe_copy() seeding fails silently when ~/.config/hypr is not writable
-- (a Home Manager / nix-store symlink, for one).
--
-- Requiring scheme.current directly meant any single consumer could take the
-- entire Hyprland config down over a generated file. Everything goes through
-- here instead, so the fallback lives in exactly one place and a new file
-- cannot reintroduce the problem by requiring the wrong thing.
local ok, scheme = pcall(require, "scheme.current")
if not ok or type(scheme) ~= "table" then
    scheme = require("scheme.default")
end
return scheme
