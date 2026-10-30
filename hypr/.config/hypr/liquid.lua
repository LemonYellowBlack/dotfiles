-- liquid.lua — the Liquid shell (Quickshell config "liquid") and the Hyprland look it's drawn for.
-- Required from hyprland.lua just before host.lua, so a host still has the last word (hotdog's
-- border_size = 3 wins over the 2 here).
--
-- The shell reserves 40 px at the top and 8 px on the other edges for its frame (Theme.barH and
-- Theme.edge in quickshell/.config/quickshell/liquid/config/Theme.qml); gaps_out sits inside that.

local mod = "SUPER"
local shell = "qs -c liquid ipc call shell "

hl.on("hyprland.start", function()
    hl.exec_cmd("qs -c liquid -n -d")
end)


-----------------
---- COLORS ----
-----------------

-- The same three layers as the shell's Theme.qml: palette names (kanagawa/palette.lua), the
-- tokens below, named as in Theme.qml, and the border and shadows built from them. The two
-- files can't read each other, so a token changed in Theme.qml needs changing here too.
local p = require(os.getenv("HOME") .. "/.config/kanagawa/palette.lua")

local accent     = p.carpYellow    -- focus, active, primary
local accentSoft = p.oldWhite      -- the pale start of accent fills
local accentAlt  = p.autumnYellow  -- the deep end of accent fills
local accentCool = p.crystalBlue   -- the cool counterpart
local line       = p.sumiInk6      -- idle borders
local shadow     = p.abyss         -- under windows

-- The focused window's border: Theme.gAccent with crystal blue in front, turning (see below).
local activeBorder = { colors = { p.rgba(accentCool), p.rgba(accentSoft), p.rgba(accent), p.rgba(accentAlt) }, angle = 45 }


---------------
---- LOOK ----
---------------

hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        col = {
            active_border   = activeBorder,
            inactive_border = p.rgba(line, 0.533),
        },
    },

    decoration = {
        rounding = 14,

        shadow = {
            enabled        = true,
            range          = 24,
            render_power   = 3,
            color          = p.rgba(shadow, 0.6),
            color_inactive = p.rgba(shadow, 0.4),
        },

        -- Frosted glass behind translucent windows. kitty is opaque until background_opacity is
        -- set in kitty.conf (0.85 is a good start); the shell turns blur off on battery (eco).
        blur = {
            enabled  = true,
            size     = 6,
            passes   = 2,
            vibrancy = 0.18,
        },
    },
})

-- The border's gradient turns, one lap every 6 s. Eco pauses it on battery.
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.animation({ leaf = "borderangle", enabled = true, speed = 60, bezier = "linear", style = "loop" })

-- The shell animates its own surfaces; the veil behind the overview and power menu gets blurred.
hl.layer_rule({ name = "liquid-still", match = { namespace = "^liquid" }, no_anim = true })
hl.layer_rule({ name = "liquid-veil-blur", match = { namespace = "liquid-veil" }, blur = true, ignore_alpha = 0.2 })


----------------
---- BINDS ----
----------------

-- Each shell bind falls back to what the key did before, in case the shell isn't running.
hl.unbind(mod .. " + D")
hl.unbind(mod .. " + F1")
hl.bind(mod .. " + Space",      hl.dsp.exec_cmd(shell .. "toggle launcher || fuzzel"))
hl.bind(mod .. " + F1",     hl.dsp.exec_cmd(shell .. "toggle dash || ~/.local/bin/statuspopup"))
hl.bind(mod .. " + A",      hl.dsp.exec_cmd(shell .. "toggle control"))
hl.bind(mod .. " + N",      hl.dsp.exec_cmd(shell .. "toggle control"))
hl.bind(mod .. " + Tab",    hl.dsp.exec_cmd(shell .. "toggle overview"))
hl.bind(mod .. " + slash",  hl.dsp.exec_cmd(shell .. "toggle keys"))
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd(shell .. "toggle power"))
hl.bind(mod .. " + Z",      hl.dsp.exec_cmd(shell .. "toggleBar"))
