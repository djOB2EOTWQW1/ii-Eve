#!/usr/bin/env python3
"""Uninstall one Argos translation package pair. Args: <from_code> <to_code>."""
import sys

import argostranslate.package


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <from> <to>", file=sys.stderr)
        return 2
    from_code, to_code = sys.argv[1], sys.argv[2]

    installed = argostranslate.package.get_installed_packages()
    match = next(
        (p for p in installed if p.from_code == from_code and p.to_code == to_code),
        None,
    )
    if match is None:
        print(f"Not installed: {from_code}->{to_code}", file=sys.stderr)
        return 0
    argostranslate.package.uninstall(match)
    print(f"Uninstalled {from_code}->{to_code}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
