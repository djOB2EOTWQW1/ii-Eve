#!/usr/bin/env bash
set -euo pipefail

# Args: <image_path> <tessdata_dir> <lang_arg>
# Example: tesseract-ocr.sh /tmp/x.png ~/.local/share/tessdata "jpn+eng"
# Output: GCloud-Vision-shaped JSON on stdout.

IMG="${1:?image path required}"
TESSDATA_DIR="${2:-$HOME/.local/share/tessdata}"
if [[ -z "$TESSDATA_DIR" ]]; then
    TESSDATA_DIR="$HOME/.local/share/tessdata"
fi
LANG_ARG="${3:?lang arg required}"

if ! command -v tesseract >/dev/null 2>&1; then
    jq -n '{error: {code: 127, message: "tesseract not installed"}}'
    exit 0
fi

TSV=$(tesseract "$IMG" stdout --tessdata-dir "$TESSDATA_DIR" -l "$LANG_ARG" --psm 3 -c tessedit_create_tsv=1 2>/dev/null || true)

if [[ -z "$TSV" ]]; then
    jq -n '{error: {code: 1, message: "tesseract produced no output"}}'
    exit 0
fi

echo "$TSV" | awk -F'\t' '
BEGIN {
    OFS="\t"
    print "level\tblock\tpara\tline\tword\tleft\ttop\twidth\theight\tconf\ttext"
}
NR == 1 { next }
$1 == 1 || $1 == 4 { next }
$1 == 2 { print "block", $3, 0, 0, 0, $7, $8, $9, $10, $11, "" ; next }
$1 == 3 { print "para",  $3, $4, 0, 0, $7, $8, $9, $10, $11, "" ; next }
$1 == 5 && $11+0 >= 30 {
    gsub(/\\/, "\\\\", $12); gsub(/"/, "\\\"", $12); gsub(/\t/, " ", $12)
    print "word", $3, $4, $5, $6, $7, $8, $9, $10, $11, $12
}
' | python3 -c '
import sys, json
blocks = {}
paras  = {}
words  = []
for line in sys.stdin.readlines()[1:]:
    parts = line.rstrip("\n").split("\t")
    if len(parts) != 11: continue
    lvl, bidx, pidx, lidx, widx, x, y, w, h, conf, text = parts
    bidx, pidx, lidx, widx = map(int, (bidx, pidx, lidx, widx))
    x, y, w, h = map(int, (x, y, w, h))
    conf = float(conf)
    if lvl == "block":
        blocks[bidx] = {"x":x,"y":y,"w":w,"h":h,"conf":conf,"paragraphs":{}}
    elif lvl == "para":
        paras[(bidx,pidx)] = {"x":x,"y":y,"w":w,"h":h,"words":[],"lines":{}}
        blocks.setdefault(bidx, {"x":x,"y":y,"w":w,"h":h,"conf":0,"paragraphs":{}})["paragraphs"][pidx] = paras[(bidx,pidx)]
    elif lvl == "word":
        para = paras.setdefault((bidx,pidx), {"x":x,"y":y,"w":w,"h":h,"words":[],"lines":{}})
        para["words"].append({"x":x,"y":y,"w":w,"h":h,"text":text,"line":lidx,"idx":widx,"conf":conf})

def vertices(x,y,w,h):
    return [{"x":x,"y":y},{"x":x+w,"y":y},{"x":x+w,"y":y+h},{"x":x,"y":y+h}]

out_blocks = []
for bidx in sorted(blocks):
    b = blocks[bidx]
    out_paragraphs = []
    for pidx in sorted(b["paragraphs"]):
        p = b["paragraphs"][pidx]
        words_by_line = {}
        for w in p["words"]:
            words_by_line.setdefault(w["line"], []).append(w)
        for ln in words_by_line:
            words_by_line[ln].sort(key=lambda w: w["idx"])
        out_words = []
        word_confs = []
        all_words = sorted(p["words"], key=lambda w: (w["line"], w["idx"]))
        for i, w in enumerate(all_words):
            line_words = words_by_line[w["line"]]
            is_last_in_line = (w is line_words[-1])
            is_last_in_para = (i == len(all_words)-1)
            brk = "LINE_BREAK" if is_last_in_line and not is_last_in_para else "SPACE"
            if is_last_in_para:
                brk = "LINE_BREAK"
            out_words.append({
                "boundingBox": {"vertices": vertices(w["x"],w["y"],w["w"],w["h"])},
                "symbols": [{
                    "text": w["text"],
                    "property": {"detectedBreak": {"type": brk}}
                }]
            })
            word_confs.append(w["conf"])
        if not out_words: continue
        avg_conf = (sum(word_confs)/len(word_confs))/100.0
        out_paragraphs.append({
            "boundingBox": {"vertices": vertices(p["x"],p["y"],p["w"],p["h"])},
            "words": out_words,
            "confidence": avg_conf
        })
    if not out_paragraphs: continue
    block_conf = sum(p["confidence"] for p in out_paragraphs)/len(out_paragraphs)
    out_blocks.append({
        "boundingBox": {"vertices": vertices(b["x"],b["y"],b["w"],b["h"])},
        "paragraphs": out_paragraphs,
        "confidence": block_conf
    })

result = {"responses": [{"fullTextAnnotation": {"pages": [{"blocks": out_blocks}]}}]}
print(json.dumps(result))
'
