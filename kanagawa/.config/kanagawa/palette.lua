-- palette.lua — Kanagawa Wave by its kanagawa.nvim names, for Hyprland's Lua config. The same
-- names and values are in the Liquid shell's Theme.qml and in palette.conf (hyprlock), so a
-- color is called the same thing everywhere.
--
-- Colors are bare hex; rgba() puts one in Hyprland's syntax, at an opacity from 0 to 1:
--     p.rgba(p.crystalBlue)        --> "rgba(7E9CD8ff)"
--     p.rgba(p.sumiInk6, 0.533)    --> "rgba(54546D88)"
-- Configs read colors through tokens (roles.lua, liquid.lua) rather than straight from here.

local p = {
    sumiInk0      = "16161D",
    sumiInk1      = "181820",
    sumiInk2      = "1A1A22",
    sumiInk3      = "1F1F28",
    sumiInk4      = "2A2A37",
    sumiInk5      = "363646",
    sumiInk6      = "54546D",
    waveBlue1     = "223249",
    waveBlue2     = "2D4F67",
    winterGreen   = "2B3328",
    winterYellow  = "49443C",
    winterRed     = "43242B",
    winterBlue    = "252535",
    autumnGreen   = "76946A",
    autumnRed     = "C34043",
    autumnYellow  = "DCA561",
    samuraiRed    = "E82424",
    roninYellow   = "FF9E3B",
    waveAqua1     = "6A9589",
    waveAqua2     = "7AA89F",
    dragonBlue    = "658594",
    fujiWhite     = "DCD7BA",
    oldWhite      = "C8C093",
    fujiGray      = "727169",
    katanaGray    = "717C7C",
    oniViolet     = "957FB8",
    oniViolet2    = "B8B4D0",
    crystalBlue   = "7E9CD8",
    springViolet1 = "938AA9",
    springViolet2 = "9CABCA",
    springBlue    = "7FB4CA",
    lightBlue     = "A3D4D5",
    springGreen   = "98BB6C",
    boatYellow1   = "938056",
    boatYellow2   = "C0A36E",
    carpYellow    = "E6C384",
    sakuraPink    = "D27E99",
    waveRed       = "E46876",
    peachRed      = "FF5D62",
    surimiOrange  = "FFA066",
    -- Off-palette: a deeper ink than sumiInk0, for shadows (Theme.qml's abyss).
    abyss         = "0D0D12",
}

function p.rgba(hex, alpha)
    return ("rgba(%s%02x)"):format(hex, math.floor((alpha or 1) * 255 + 0.5))
end

return p
