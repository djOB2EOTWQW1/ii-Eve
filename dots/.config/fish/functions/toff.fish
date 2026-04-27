#!/usr/bin/env fish
function toff -d "Disable touchpad and restore mouse sensitivity -1"
    hyprctl keyword "device[pnp0c50:00-04f3:30aa-touchpad]:enabled" false
    hyprctl keyword "device[etps/2-elantech-touchpad]:enabled" false

    hyprctl keyword input:sensitivity -1

    echo "Touchpad disabled. Global sensitivity restored to -1"
end
