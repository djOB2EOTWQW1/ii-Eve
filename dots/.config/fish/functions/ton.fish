function ton -d "Enable touchpads at sensitivity -0.4 (mouse stays at -1)"
    hyprctl eval 'hl.device({ name = "pnp0c50:00-04f3:30aa-touchpad", enabled = true, sensitivity = -0.4 })'
    hyprctl eval 'hl.device({ name = "etps/2-elantech-touchpad", enabled = true, sensitivity = -0.4 })'
    echo "Touchpad enabled (sensitivity -0.4). Mouse stays at -1."
end
