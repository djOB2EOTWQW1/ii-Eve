#!/usr/bin/env python3
"""List installed Argos packages as JSON [{from,to}, ...]."""
import json
import sys

import argostranslate.package


def main() -> int:
    pkgs = argostranslate.package.get_installed_packages()
    out = [{"from": p.from_code, "to": p.to_code} for p in pkgs]
    json.dump(out, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
