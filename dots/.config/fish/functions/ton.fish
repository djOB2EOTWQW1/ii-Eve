#!/usr/bin/env fish
function ton -d "Enable touchpad with good sensitivity"
    hyprctl keyword "device[pnp0c50:00-04f3:30aa-touchpad]:enabled" true
    hyprctl keyword "device[etps/2-elantech-touchpad]:enabled" true

    sleep 0.25

    hyprctl keyword "device[pnp0c50:00-04f3:30aa-touchpad]:sensitivity" -0.4
    hyprctl keyword "device[etps/2-elantech-touchpad]:sensitivity" -0.4

    echo "Touchpad enabled (sensitivity 0.0). Mouse stays at -1"
end
