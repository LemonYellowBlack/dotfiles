-- The greeter's Hyprland. boot/greeter/start runs it as greetd's greeter user, and all it does is
-- show the Liquid shell's greeter.qml on every screen: no binds, no windows, nothing to do here but
-- log in. Should the greeter fail to start, ReGreet takes its place. Either way, Hyprland exits
-- once it's done, which is when greetd starts the session.

-- The screens as this machine's own Hyprland sets them up: the monitor lines from hypr's host.lua
-- (scale, the phantom output the XPS has), run with an `hl` that ignores everything else in it.
local monitors = false
local home = os.getenv("LIQUID_HOME")
if home then
    local nothing
    nothing = setmetatable({}, { __index = function() return nothing end, __call = function() return nothing end })
    local only = setmetatable({ monitor = function(spec) monitors = true; hl.monitor(spec) end },
                              { __index = function() return nothing end })
    local chunk = loadfile(home .. "/.config/hypr/host.lua", "t", setmetatable({ hl = only }, { __index = _G }))
    if chunk then pcall(chunk) end
end
if not monitors then
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
end

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")

hl.config({
    input = {
        kb_layout  = "us",
        kb_options = "caps:escape",
    },
    general = {
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 0,
    },
    decoration = {
        rounding = 0,
        shadow   = { enabled = false },
        blur     = { enabled = false },
    },
    -- The greeter animates itself, from black: a Hyprland fade on top would only blur its start.
    animations = { enabled = false },
    cursor = {
        inactive_timeout  = 3,
        hide_on_key_press = true,
    },
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        background_color         = "rgb(000000)",
        disable_watchdog_warning = true,
    },
    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})

hl.on("hyprland.start", function()
    local greeter = os.getenv("LIQUID_GREETER") or ""
    hl.exec_cmd("qs -p '" .. greeter .. "' || regreet; hyprctl dispatch 'hl.dsp.exit()'")
end)
