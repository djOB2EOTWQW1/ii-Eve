#!/usr/bin/env python3
import json
import sys

import argostranslate.translate as at


def main() -> None:
    payload = json.load(sys.stdin)
    target = payload["target"]
    strings = payload["strings"]

    translations = []
    for s in strings:
        if not s or not s.strip():
            translations.append({"translatedText": s, "detectedSourceLanguage": ""})
            continue
        try:
            src = at.identify_language(s).code
        except Exception:
            src = ""
        if not src or src == target:
            translations.append({"translatedText": s, "detectedSourceLanguage": src})
            continue
        try:
            translated = at.translate(s, src, target)
            translations.append({"translatedText": translated, "detectedSourceLanguage": src})
        except Exception as e:
            translations.append({"translatedText": s, "detectedSourceLanguage": src, "error": str(e)})

    json.dump({"translations": translations}, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
