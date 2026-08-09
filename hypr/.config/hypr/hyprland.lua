-- hyprland.lua — shared base, stowed on every machine
-- Kanagawa (Wave) — see ~/lab/dotfiles/kanagawa-palette.md
--
-- Host-specific settings (monitors, laptop-only binds) live in the
-- hypr-xps / hypr-hotdog stow packages and are required at the bottom.
--
-- Migrated from hyprland.conf (hyprlang) — deprecated since Hyprland 0.55.
-- API reference: /usr/share/hypr/stubs/hl.meta.lua, example config at
-- /usr/share/hypr/hyprland.lua.

local colors = require(os.getenv("HOME") .. "/.config/kanagawa/roles.lua")

local mod = "SUPER"


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("AQ_NO_MODIFIERS", "1")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("wl-clip-persist --clipboard regular")
    hl.exec_cmd("gammastep")
    hl.exec_cmd("udiskie --no-tray")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    -- auto-lock off by default each boot (toggle: SUPER SHIFT F9)
    hl.exec_cmd('touch "$XDG_RUNTIME_DIR/hypr-nolock"')
    -- hl.exec_cmd("waybar")
end)


---------------------
---- KEYBINDINGS ----
---------------------

hl.bind(mod .. " + Return",       hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + B",            hl.dsp.exec_cmd("zen-browser"))
hl.bind(mod .. " + Q",            hl.dsp.window.close())
hl.bind(mod .. " + V",            hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F",            hl.dsp.window.fullscreen())
hl.bind(mod .. " + D",            hl.dsp.exec_cmd("fuzzel"))
hl.bind(mod .. " + L",            hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mod .. " + C",            hl.dsp.exec_cmd("cliphist list | fuzzel -d | cliphist decode | wl-copy"))
hl.bind(mod .. " + F12",          hl.dsp.exec_cmd("~/.local/bin/caff-status"))
hl.bind(mod .. " + SHIFT + F12",  hl.dsp.exec_cmd("~/.local/bin/caff"))
hl.bind(mod .. " + F1",           hl.dsp.exec_cmd("~/.local/bin/statuspopup"))
hl.bind(mod .. " + SHIFT + F1",   hl.dsp.exec_cmd("~/.local/bin/statuspopup --persist"))
hl.bind(mod .. " + F9",           hl.dsp.exec_cmd("~/.local/bin/lock-status"))
hl.bind(mod .. " + SHIFT + F9",   hl.dsp.exec_cmd("~/.local/bin/lock-toggle"))
hl.bind("CTRL + SUPER + SHIFT + Delete", hl.dsp.exec_cmd("systemctl poweroff"))

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),    { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Screenshots
hl.bind("Print",                    hl.dsp.exec_cmd("hyprshot -m output -o ~/Pictures/Screenshots"))
hl.bind(mod .. " + Print",          hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"))
hl.bind(mod .. " + SHIFT + Print",  hl.dsp.exec_cmd("hyprshot -m window -o ~/Pictures/Screenshots"))

-- Resize mode
hl.bind(mod .. " + R", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
    hl.bind("right", hl.dsp.window.resize({ x = 30,  y = 0,   relative = true }), { repeating = true })
    hl.bind("left",  hl.dsp.window.resize({ x = -30, y = 0,   relative = true }), { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0,   y = -30, relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0,   y = 30,  relative = true }), { repeating = true })

    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)

-- Move/resize floating windows with mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Move focus / swap windows
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir,          hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. dir,  hl.dsp.window.swap({ direction = dir }))
end

-- Switch workspaces / move window to workspace
for i = 1, 10 do
    local key = i % 10  -- workspace 10 lives on key 0
    hl.bind(mod .. " + " .. key,          hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key,  hl.dsp.window.move({ workspace = i }))
end


--------------------------------
---- WINDOW AND LAYER RULES ----
--------------------------------

-- Tor Browser: float at fixed size to prevent fingerprinting via screen resolution
hl.window_rule({
    name  = "tor-browser-fixed-size",
    match = { class = "Tor Browser" },

    float          = true,
    size           = { 1600, 1000 },
    center         = true,
    suppress_event = "fullscreen maximize",
})

hl.layer_rule({
    name  = "no-blur-waybar",
    match = { namespace = "waybar" },
    blur  = false,
})


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    input = {
        kb_layout    = "us",
        kb_options   = "caps:escape",
        follow_mouse = 1,
    },

    general = {
        gaps_in     = 0,
        gaps_out    = 0,
        border_size = 1,

        -- Stop at the edge instead of wrapping to the opposite pane.
        no_focus_fallback = true,

        col = {
            active_border   = colors.focus_accent,
            inactive_border = colors.dim_accent,
        },
    },

    decoration = {
        rounding = 0,

        shadow = {
            enabled        = false,
            range          = 1,
            render_power   = 1,
            color          = "rgba(1F1F28ee)",  -- sumiInk0
            color_inactive = "rgba(1F1F28aa)",
        },

        blur = {
            enabled  = false,
            size     = 3,
            passes   = 1,
            vibrancy = 0.2,
        },
    },

    dwindle = {
        force_split    = 2,
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },

    ecosystem = {
        no_update_news  = true,
        no_donation_nag = true,
    },
})


--------------------
---- ANIMATIONS ----
--------------------

hl.curve("smooth", { type = "bezier", points = { { 0.15, 0.5 }, { 0.20, 1.0 } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 5, bezier = "smooth", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "smooth", style = "popin 80%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 6, bezier = "smooth" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "smooth", style = "slide" })
hl.animation({ leaf = "layers",     enabled = true, speed = 4, bezier = "smooth", style = "fade" })


-- Host-specific overrides — MUST stay last. Lua executes top to bottom, so
-- anything required here wins over the shared base above.
-- Provided by the hypr-xps / hypr-hotdog stow packages.
require("host")
