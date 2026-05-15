#!/usr/bin/env fish
function zawarp-off -d "Warp and Zapret has been disable"
    sudo systemctl disable --now warp-svc
    sudo systemctl disable --now zapret_discord_youtube.service
end
