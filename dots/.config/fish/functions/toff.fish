function toff -d "Disable touchpads, restore global sensitivity -1"
    hyprctl eval 'hl.device({ name = "pnp0c50:00-04f3:30aa-touchpad", enabled = false })'
    hyprctl eval 'hl.device({ name = "etps/2-elantech-touchpad", enabled = false })'
    hyprctl eval 'hl.config({ input = { sensitivity = -1 } })'
    echo "Touchpad disabled. Global sensitivity restored to -1."
end
