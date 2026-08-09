-- host.lua — hotdog (desktop)
-- Required at the end of hypr/.config/hypr/hyprland.lua.
-- Lua executes top to bottom, so anything here wins over the shared base.

hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@60", position = "0x0", scale = 2 })

-- Thicker window borders. At scale 2 on a 55" panel viewed from a distance,
-- the shared 1px border is effectively invisible.
hl.config({
    general = {
        border_size = 3,
    },
})
