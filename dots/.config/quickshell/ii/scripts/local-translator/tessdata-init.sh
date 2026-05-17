#!/usr/bin/env bash
set -euo pipefail

USER_DIR="${HOME}/.local/share/tessdata"
SYSTEM_DIR="/usr/share/tessdata"

mkdir -p "$USER_DIR"

if [[ -d "$SYSTEM_DIR" ]]; then
    for src in "$SYSTEM_DIR"/*.traineddata; do
        [[ -e "$src" ]] || continue
        name="$(basename "$src")"
        target="${USER_DIR}/${name}"
        if [[ ! -e "$target" && ! -L "$target" ]]; then
            ln -s "$src" "$target"
        fi
    done
fi
