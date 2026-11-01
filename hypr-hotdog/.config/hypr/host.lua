-- host.lua — hotdog (desktop)
-- Required at the end of hypr/.config/hypr/hyprland.lua.
-- Lua executes top to bottom, so anything here wins over the shared base.

-- The TV is on the RTX 4070 Ti's HDMI port (HDMI-A-2). It used to be on the
-- motherboard's (HDMI-A-1, the AMD iGPU); that rule stays so the old port works.
hl.monitor({ output = "HDMI-A-2", mode = "3840x2160@30", position = "0x0", scale = 2 })
hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@30", position = "0x0", scale = 2 })

-- Render on the RTX. The firmware marks the iGPU as boot VGA, so Aquamarine
-- would pick it otherwise, and then Sunshine's screencopy frames live on the
-- AMD GPU and NVENC can't import them (a black stream). The first device is
-- the primary renderer; the iGPU stays listed so its ports keep working.
-- /dev/dri/rtx and /dev/dri/amd-igpu come from /etc/udev/rules.d/61-gpu.rules
-- (by PCI address, since cardN numbers can swap between boots).
hl.env("AQ_DRM_DEVICES", "/dev/dri/rtx:/dev/dri/amd-igpu")

-- GPU vendor env for hardware video accel: VA-API and GLX on the RTX 4070 Ti.
-- This value was previously hardcoded in the shared config, which silently
-- broke VA-API on the XPS (an Intel/NVIDIA Optimus laptop).
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

-- Thicker window borders. At scale 2 on a 55" panel viewed from a distance,
-- the shared 1px border is effectively invisible.
hl.config({
    general = {
        border_size = 3,
    },
})

-- Auto-start Sunshine for Moonlight streaming. Its systemd unit is enabled
-- but only WantedBy=graphical-session.target, which nothing here activates
-- (no uwsm/session-manager in use), so it never starts on its own otherwise.
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start app-dev.lizardbyte.app.Sunshine.service")
end)
