-- host.lua — Dell XPS (laptop)
-- Required at the end of hypr/.config/hypr/hyprland.lua.
-- Lua executes top to bottom, so anything here wins over the shared base.

-- HiDPI internal panel. Unknown-1 is a phantom output this machine advertises.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 2 })
hl.monitor({ output = "Unknown-1", disabled = true })

-- Backlight — requires a /sys/class/backlight device
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

-- Lid
hl.bind("switch:Lid Switch", hl.dsp.exec_cmd("~/.local/bin/lock-if-enabled"), { locked = true })

-- Battery
hl.bind("SUPER + F2",         hl.dsp.exec_cmd("~/.local/bin/batterypopup"))
hl.bind("SUPER + SHIFT + F2", hl.dsp.exec_cmd("~/.local/bin/batterypopup --persist"))

-- Touchpad
hl.bind("SUPER + F10",         hl.dsp.exec_cmd("~/.local/bin/touchpad-status"))
hl.bind("SUPER + SHIFT + F10", hl.dsp.exec_cmd("~/.local/bin/touchpad-toggle"))

-- PRIME dGPU toggle — hybrid graphics only. Never define this on a machine
-- where the NVIDIA card is the only GPU driving the display.
hl.bind("SUPER + F11",         hl.dsp.exec_cmd("~/.local/bin/gpu-status"))
hl.bind("SUPER + SHIFT + F11", hl.dsp.exec_cmd("~/.local/bin/gpu-toggle"))

hl.config({
    input = {
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            clickfinger_behavior = true,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
