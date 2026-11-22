#!/usr/bin/env python3
"""Fail when a newly added `lib/` file is not exercised by the test suite.

The aggregate coverage gate lets a new untested module hide behind well-covered
code, and a per-file allowlist of every legacy gap would need constant
maintenance. This gate is narrower: it only looks at files **added by the pull
request** (git diff against the base commit) and requires each of them to be
measured by `flutter test --coverage` and to clear `MIN_NEW_FILE_COVERAGE`.

On a push build there is no base commit, so the gate is a no-op; the pull-request
run is the one that matters.

Usage:
    python scripts/check_new_file_coverage.py --base <git-ref>
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys

# A file this small is usually a model constant or a one-widget wrapper; the
# line-count floor keeps the gate from demanding tests for trivia.
MIN_FILE_LINES = 40
MIN_NEW_FILE_COVERAGE = 60.0

# Flutter generates these from the ARBs. They are committed for deterministic
# builds but are not hand-written code the tests can meaningfully exercise.
GENERATED_PREFIXES = ("lib/l10n/",)

LCOV = pathlib.Path("coverage/lcov.info")


def added_lib_files(base: str) -> list[str]:
    """Paths added between `base` and HEAD, relative and POSIX-style."""
    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=A", base, "--", "lib"],
        capture_output=True,
        text=True,
        check=True,
    )
    return [
        line.strip().replace("\\", "/")
        for line in result.stdout.splitlines()
        if line.strip().endswith(".dart")
    ]


def read_lcov(path: pathlib.Path) -> dict[str, tuple[int, int]]:
    """Return {path suffix: (lines found, lines hit)}.

    lcov records absolute paths; keying by suffix lets a relative repo path find
    its record without depending on the checkout location.
    """
    files: dict[str, tuple[int, int]] = {}
    current: str | None = None
    found = hit = 0
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if line.startswith("SF:"):
            current = line[3:].strip().replace("\\", "/")
            found = hit = 0
        elif line.startswith("LF:"):
            found = int(line[3:])
        elif line.startswith("LH:"):
            hit = int(line[3:])
        elif line.startswith("end_of_record") and current is not None:
            files[current] = (found, hit)
            current = None
    return files


def lookup(files: dict[str, tuple[int, int]], rel: str) -> tuple[int, int] | None:
    for path, counts in files.items():
        if path.endswith("/" + rel) or path == rel:
            return counts
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--base",
        nargs="?",
        const="",
        default="",
        help="base git ref/sha of the pull request; empty disables the gate",
    )
    args = parser.parse_args()

    if not args.base.strip():
        print("New-file coverage: no base ref (push build); skipped")
        return 0

    try:
        paths = added_lib_files(args.base)
    except subprocess.CalledProcessError as error:
        print(f"error: git diff against {args.base} failed: {error}")
        return 1

    if not paths:
        print("New-file coverage: no lib/ files added")
        return 0

    if not LCOV.exists():
        print(f"error: {LCOV} is missing; run flutter test --coverage first")
        return 1
    files = read_lcov(LCOV)

    errors: list[str] = []
    print(
        f"New-file coverage: {MIN_NEW_FILE_COVERAGE:.0f}% floor for added files "
        f">= {MIN_FILE_LINES} lines"
    )
    for rel in paths:
        if any(rel.startswith(prefix) for prefix in GENERATED_PREFIXES):
            print(f"  skip {rel} (generated)")
            continue
        path = pathlib.Path(rel)
        if not path.exists():
            continue
        lines = len(path.read_text(encoding="utf-8", errors="ignore").splitlines())
        if lines < MIN_FILE_LINES:
            print(f"  skip {rel} ({lines} lines, below the {MIN_FILE_LINES}-line floor)")
            continue
        counts = lookup(files, rel)
        if counts is None:
            errors.append(f"{rel}: added file is not measured by any test")
            print(f"  FAIL {rel}: not present in coverage/lcov.info")
            continue
        found, hit = counts
        if found == 0:
            continue
        percent = hit / found * 100
        if percent < MIN_NEW_FILE_COVERAGE:
            errors.append(
                f"{rel}: {percent:.2f}% is below the {MIN_NEW_FILE_COVERAGE:.0f}% "
                "new-file floor"
            )
            print(f"  FAIL {percent:6.2f}%  {rel}")
        else:
            print(f"  ok   {percent:6.2f}%  {rel}")

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
