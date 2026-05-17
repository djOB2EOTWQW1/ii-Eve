#!/usr/bin/env bash
set -euo pipefail

CODE="${1:?tess code required}"
USER_FILE="${HOME}/.local/share/tessdata/${CODE}.traineddata"

if [[ -e "$USER_FILE" || -L "$USER_FILE" ]]; then
    rm -f "$USER_FILE"
    echo "Removed: $CODE"
else
    echo "Not present in user dir: $CODE"
fi
