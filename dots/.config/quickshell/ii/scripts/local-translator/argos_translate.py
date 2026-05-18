#!/usr/bin/env python3
"""Translate strings via argostranslate.

stdin JSON: {"target": "ru", "strings": [...], "sources": ["en","ja",...]}
stdout JSON: {"translations": [{"translatedText": str, "detectedSourceLanguage": str}, ...]}

`sources` is a list of candidate argos language codes to try (in order). The
script picks the first source whose translation succeeds and differs from the
input. Falls back to the original string if every source fails.
"""
import json
import sys

import argostranslate.translate as at


def _normalize(code: str) -> str:
    return (code or "").split("_")[0].split("-")[0].lower()


def _translate_one(text: str, target: str, sources: list[str]) -> tuple[str, str]:
    for raw_src in sources:
        src = _normalize(raw_src)
        if not src or src == target:
            continue
        try:
            translated = at.translate(text, src, target)
        except Exception:
            continue
        if translated and translated != text:
            return translated, src
    return text, ""


def main() -> None:
    payload = json.load(sys.stdin)
    target = _normalize(payload["target"])
    strings = payload["strings"]
    sources = payload.get("sources", []) or []

    translations = []
    for s in strings:
        if not s or not s.strip():
            translations.append({"translatedText": s, "detectedSourceLanguage": ""})
            continue
        translated, src = _translate_one(s, target, sources)
        translations.append({"translatedText": translated, "detectedSourceLanguage": src})

    json.dump({"translations": translations}, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
