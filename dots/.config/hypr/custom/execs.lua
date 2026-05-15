-- put former exec-once commands inside the func and former exec commands outside
hl.on("hyprland.start", function()
    -- Disable touchpads
    hl.exec_cmd('hyprctl keyword device["pnp0c50:00-04f3:30aa-touchpad"]:enabled false')
    hl.exec_cmd('hyprctl keyword device["etps/2-elantech-touchpad"]:enabled false')
end)
