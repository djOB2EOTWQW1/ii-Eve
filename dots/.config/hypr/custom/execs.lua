-- Disable touchpads at config load (replaces former `exec-once = hyprctl keyword ...`)
hl.device({ name = "pnp0c50:00-04f3:30aa-touchpad", enabled = false })
hl.device({ name = "etps/2-elantech-touchpad", enabled = false })
