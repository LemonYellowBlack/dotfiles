-- Kanagawa semantic roles — hyprland variables
-- Source of truth: ~/lab/dotfiles/kanagawa-palette.md
--
-- Required from hyprland.lua via
-- `require(os.getenv("HOME") .. "/.config/kanagawa/roles.lua")`.
-- Replaces roles.hypr, which hyprlang sourced. See roles.conf / roles.css
-- for the other formats.
--
-- Each role is a palette.lua color, as bare hex; wrap it with p.rgba() where
-- it's used.

local p = require(os.getenv("HOME") .. "/.config/kanagawa/palette.lua")

return {
    content      = p.sumiInk3,
    chrome       = p.sumiInk0,
    focus_accent = p.fujiGray,
    dim_accent   = p.sumiInk4,
}
