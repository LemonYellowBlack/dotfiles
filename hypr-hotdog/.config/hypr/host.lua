-- host.lua — hotdog (desktop)
-- Required at the end of hypr/.config/hypr/hyprland.lua.
-- Lua executes top to bottom, so anything here wins over the shared base.

hl.monitor({ output = "HDMI-A-1", mode = "3840x2160@30", position = "0x0", scale = 2 })

-- GPU vendor env for hardware video accel. The physical monitor is wired to
-- the AMD iGPU, but NVENC (used by Sunshine) needs the RTX 4070 Ti targeted
-- via VA-API/GLX. This value was previously hardcoded in the shared config,
-- which silently broke VA-API on the XPS (an Intel/NVIDIA Optimus laptop).
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
