#!/usr/bin/env fish
function zawarp-on -d "Warp and Zapret has been started"
    sudo systemctl enable --now warp-svc
    sudo systemctl enable --now zapret_discord_youtube.service
end
