#!/usr/bin/env bash
set -euo pipefail

# Output JSON: {"system": ["eng","rus",...], "user": ["jpn",...]}
# 'user' = .traineddata that is a regular file (not symlink) in ~/.local/share/tessdata.
# 'system' = .traineddata in /usr/share/tessdata, OR a symlink in user dir pointing into /usr/share.

SYSTEM_DIR="/usr/share/tessdata"
USER_DIR="${HOME}/.local/share/tessdata"

list_dir_files() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    find "$dir" -maxdepth 1 -name '*.traineddata' -printf '%f\n' 2>/dev/null \
        | sed 's/\.traineddata$//' \
        | sort -u
}

sys_files=$(list_dir_files "$SYSTEM_DIR")

user_real=""
if [[ -d "$USER_DIR" ]]; then
    user_real=$(find "$USER_DIR" -maxdepth 1 -type f -name '*.traineddata' -printf '%f\n' 2>/dev/null \
        | sed 's/\.traineddata$//' \
        | sort -u)
fi

jq -n \
    --arg sys "$sys_files" \
    --arg usr "$user_real" \
    '{
        system: ($sys | split("\n") | map(select(length > 0))),
        user:   ($usr | split("\n") | map(select(length > 0)))
    }'
