#!/usr/bin/env python3
"""Enforce the app coverage ratchet produced by `flutter test --coverage`.

The baseline on 2026-11-13 was 76.45% line coverage (full suite). The gate sits
~1 point below that so ordinary incremental work passes, while deleting
tests, breaking coverage collection or dropping a large covered module fails.
Ratchet this constant upward when coverage improves.
"""

from __future__ import annotations

import pathlib
import sys

MIN_LINE_COVERAGE = 74.0
LCOV = pathlib.Path("coverage/lcov.info")


def line_coverage(path: pathlib.Path) -> float:
    found = 0
    hit = 0
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if line.startswith("LF:"):
            found += int(line[3:])
        elif line.startswith("LH:"):
            hit += int(line[3:])
    if found == 0:
        raise ValueError(f"{path} contains no LF records")
    return hit / found * 100


def main() -> int:
    if not LCOV.exists():
        print(f"error: {LCOV} is missing; run flutter test --coverage first")
        return 1
    try:
        actual = line_coverage(LCOV)
    except (OSError, ValueError) as error:
        print(f"error: could not read coverage: {error}")
        return 1
    print(f"App line coverage: {actual:.2f}% (minimum {MIN_LINE_COVERAGE:.2f}%)")
    if actual < MIN_LINE_COVERAGE:
        print("error: app coverage regressed below the ratchet")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
