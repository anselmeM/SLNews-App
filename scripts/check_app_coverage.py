#!/usr/bin/env python3
"""Enforce the app quality gates produced by `flutter test --coverage`.

Three gates run in CI after the test step; this script is the single entry point
so the thresholds live next to the tests they describe.

1. Total line coverage — must stay at or above `MIN_LINE_COVERAGE`.

2. Per-file floors for the critical modules in `CRITICAL_FLOORS`. There is
   deliberately no branch threshold: Flutter 3.47's coverage run emits only
   `DA` line records, with no `BRDA` (branch) and no `FNF`/`FNH` (function)
   records — checked against the lcov this suite actually produces, so a branch
   number would have to be invented. The per-file floors stand in for it: they
   make an untested critical module fail the build instead of disappearing
   inside the total.

3. File budget — no hand-written file under `lib/` may grow past
   `FAIL_OVER_LINES`; anything past `WARN_OVER_LINES` is printed so the next
   extraction is noticed before it becomes debt. Seed catalogues are exempt.

Ratchet the constants upward when coverage improves. Lowering a floor needs a
comment explaining why, in the same commit.
"""

from __future__ import annotations

import pathlib
import sys

# Total line coverage. Baselines: 76.45% on 2026-11-13, 76.12% once the push
# suite joined the measured run, 77.61% after the Following rebuild and the
# `JsonArticleMapper` tests, 78.00% after the Sports league page, then 76.31%
# when the city-locations UI was deleted (removing well-covered code lowers the
# ratio without losing any test). The floor tracks the baseline ~0.8 points
# below, so ordinary incremental work passes while a dropped module does not.
MIN_LINE_COVERAGE = 75.5

# Critical modules: a floor each, set ~2 points under the measured value so
# refactors inside a file pass but deleting or bypassing its tests fails.
# Paths are POSIX-style and matched against the lcov `SF:` records.
CRITICAL_FLOORS: dict[str, float] = {
    "lib/core/data/sources/api_client.dart": 83.0,
    "lib/core/data/sources/sl_news_api_source.dart": 92.0,
    "lib/core/data/repositories/offline_first_article_repository.dart": 91.0,
    "lib/core/data/sync/remote_sync_source.dart": 89.0,
    "lib/core/domain/sync/sync_state.dart": 83.0,
    "lib/core/push/push_service.dart": 48.0,
    # Startup/auth/storage orchestration now has an in-memory bootstrap test;
    # keep it from silently regressing back to zero coverage.
    "lib/core/providers/app_bootstrap.dart": 65.0,
    # Ingestion and sports-source floors: these paths fail soft to seed content,
    # so a coverage drop is otherwise invisible until a feed goes missing.
    "lib/core/data/sources/feed_source.dart": 95.0,
    "lib/core/data/sources/espn_source.dart": 85.0,
    "lib/core/data/sources/league_news_source.dart": 90.0,
    "lib/core/data/sources/rss_feed_source.dart": 80.0,
    "lib/core/data/sources/rss_wire.dart": 70.0,
}

# Structural budget. `docs/TECH-DEBT-AUDIT-2026-11-13.md` proposes warn >500 /
# fail >800; the split work in this commit took every page well under 500.
WARN_OVER_LINES = 500
FAIL_OVER_LINES = 800
LIB = pathlib.Path("lib")
SEED_DIRS = ("lib/core/data/seed/",)

LCOV = pathlib.Path("coverage/lcov.info")


def read_lcov(path: pathlib.Path) -> dict[str, tuple[int, int]]:
    """Return {source file: (lines found, lines hit)}."""
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


def check_coverage(files: dict[str, tuple[int, int]]) -> list[str]:
    errors: list[str] = []
    found = sum(f for f, _ in files.values())
    hit = sum(h for _, h in files.values())
    if found == 0:
        return ["error: coverage/lcov.info contains no LF records"]

    total = hit / found * 100
    print(f"Total line coverage: {total:.2f}% (minimum {MIN_LINE_COVERAGE:.2f}%)")
    if total < MIN_LINE_COVERAGE:
        errors.append(
            f"total line coverage {total:.2f}% is below the {MIN_LINE_COVERAGE:.2f}% floor"
        )

    for path, floor in CRITICAL_FLOORS.items():
        if path not in files:
            errors.append(f"{path}: missing from coverage (was it renamed or dropped?)")
            continue
        file_found, file_hit = files[path]
        if file_found == 0:
            continue
        percent = file_hit / file_found * 100
        state = "ok" if percent >= floor else "FAIL"
        print(f"  {state:4} {percent:6.2f}% (floor {floor:.2f}%)  {path}")
        if percent < floor:
            errors.append(f"{path}: {percent:.2f}% is below its {floor:.2f}% floor")

    return errors


def check_file_budget() -> list[str]:
    errors: list[str] = []
    warnings: list[str] = []
    for path in sorted(LIB.rglob("*.dart")):
        name = path.as_posix()
        if any(name.startswith(seed) for seed in SEED_DIRS):
            continue
        lines = len(path.read_text(encoding="utf-8", errors="ignore").splitlines())
        if lines > FAIL_OVER_LINES:
            errors.append(f"{name}: {lines} lines exceeds the {FAIL_OVER_LINES}-line budget")
        elif lines > WARN_OVER_LINES:
            warnings.append(f"{name}: {lines} lines is over the {WARN_OVER_LINES}-line warning")

    print(f"File budget: {FAIL_OVER_LINES} hard limit, {WARN_OVER_LINES} warning")
    for warning in warnings:
        print(f"  warn {warning}")
    if not warnings:
        print("  ok   no file over the warning line")
    return errors


def main() -> int:
    if not LCOV.exists():
        print(f"error: {LCOV} is missing; run flutter test --coverage first")
        return 1
    try:
        files = read_lcov(LCOV)
    except (OSError, ValueError) as error:
        print(f"error: could not read coverage: {error}")
        return 1

    errors = check_coverage(files)
    errors += check_file_budget()

    if errors:
        print()
        for error in errors:
            print(f"error: {error}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
