-- Kanagawa semantic roles — hyprland variables
-- Source of truth: ~/lab/dotfiles/kanagawa-palette.md
--
-- Required from hyprland.lua via
-- `require(os.getenv("HOME") .. "/.config/kanagawa/roles.lua")`.
-- Replaces roles.hypr, which hyprlang sourced. See roles.conf / roles.css
-- for the other formats.

return {
    content      = "rgba(1F1F28ff)",
    chrome       = "rgba(16161Dff)",
    focus_accent = "rgba(727169ff)",
    dim_accent   = "rgba(2A2A37ff)",
}
