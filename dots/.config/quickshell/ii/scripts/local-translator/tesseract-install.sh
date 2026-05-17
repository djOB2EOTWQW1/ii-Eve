#!/usr/bin/env bash
set -euo pipefail

# Args: <tess_code> <model>   model = fast | best
CODE="${1:?tess code required}"
MODEL="${2:-fast}"
USER_DIR="${HOME}/.local/share/tessdata"
SYS_FILE="/usr/share/tessdata/${CODE}.traineddata"
USER_FILE="${USER_DIR}/${CODE}.traineddata"

mkdir -p "$USER_DIR"

if [[ -e "$USER_FILE" || -L "$USER_FILE" ]]; then
    echo "Already installed: $CODE"
    exit 0
fi

if [[ -f "$SYS_FILE" ]]; then
    ln -s "$SYS_FILE" "$USER_FILE"
    echo "Linked from system: $CODE"
    exit 0
fi

case "$MODEL" in
    fast) REPO="tessdata_fast" ;;
    best) REPO="tessdata_best" ;;
    *) echo "Unknown model: $MODEL" >&2; exit 2 ;;
esac

URL="https://github.com/tesseract-ocr/${REPO}/raw/main/${CODE}.traineddata"
TMP="${USER_FILE}.partial"
if ! curl -fL --connect-timeout 10 --max-time 600 -o "$TMP" "$URL"; then
    rm -f "$TMP"
    echo "Download failed: $URL" >&2
    exit 3
fi
mv "$TMP" "$USER_FILE"
echo "Downloaded: $CODE"
