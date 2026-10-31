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

-- Slots and tokens come from this machine's theme (theme/), by way of the generated
-- ~/.config/theme/theme.lua, so t.accent here is the shell's Theme.accent. Change them in the
-- shell's theme drawer or with retheme.
-- Before the first retheme there is no theme.lua: every color is then flagged, line by line, and
-- the binds and the rest still load.
local ok, t = pcall(require, os.getenv("HOME") .. "/.config/theme/theme.lua")
if not ok then t = { rgba = function() return "rgba(nil)" end } end

-- The focused window's border: Theme.gAccent with crystal blue in front, turning (see below).
local activeBorder = { colors = { t.rgba(t.accentCool), t.rgba(t.accentSoft), t.rgba(t.accent), t.rgba(t.accentAlt) }, angle = 45 }


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
            inactive_border = t.rgba(t.line, 0.533),
        },
    },

    decoration = {
        rounding = 14,

        shadow = {
            enabled        = true,
            range          = 24,
            render_power   = 3,
            color          = t.rgba(t.shadow, 0.6),
            color_inactive = t.rgba(t.shadow, 0.4),
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
