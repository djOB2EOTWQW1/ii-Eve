-- See https://wiki.hyprland.org/Configuring/Binds/

--##! Zoom
local function zoomBy(factor)
    local cur = hl.get_config("cursor:zoom_factor")
    local new = cur * factor
    if new < 1 then new = 1 end
    hl.config({ cursor = { zoom_factor = new } })
end
hl.bind("SHIFT + SUPER + mouse_down", function() zoomBy(1.2) end, { description = "Zoom: Zoom in" })
hl.bind("SHIFT + SUPER + mouse_up", function() zoomBy(0.5) end, { description = "Zoom: Zoom out" })

--##! Custom Apps
hl.bind("SUPER + D", hl.dsp.exec_cmd("vesktop"), { description = "Custom Apps: Vesktop" })
hl.bind("SUPER + W",
    hl.dsp.exec_cmd("env MOZ_DRM_DEVICE=/dev/dri/renderD128 __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia MOZ_ENABLE_WAYLAND=1 firefox"),
    { description = "Custom Apps: Firefox" })
hl.bind("SUPER + T",
    hl.dsp.exec_cmd("env __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia AyuGram"),
    { description = "Custom Apps: AyuGram" })
hl.bind("SUPER + K", hl.dsp.exec_cmd("keepassxc"), { description = "Custom Apps: KeePassXC" })
hl.bind("SUPER + U", hl.dsp.exec_cmd("kdenlive"), { description = "Custom Apps: Kdenlive" })
hl.bind("SUPER + X", hl.dsp.exec_cmd("spotify"), { description = "Custom Apps: Spotify" })
