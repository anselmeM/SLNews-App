#!/usr/bin/env python3
"""Keep new functions from becoming review hotspots.

This is a heuristic Dart scanner, not a compiler. It deliberately measures only
two things that have repeatedly predicted change pain in this repo:

* body length (including nested blocks), and
* branch-token count (`if`/`for`/`while`/`case`/`catch`, `&&`, `||`, `?`).

Existing hotspots are grandfathered by exact `path::function` key. Shrink the
allowlist when a hotspot is split; never add to it without a follow-up issue.
The file-budget gate remains the primary structural gate; this one prevents a
new 300-line `build()` or mapper from landing unnoticed.
"""

from __future__ import annotations

import pathlib
import re
import sys

LONG_FAIL = 150
LONG_WARN = 80
COMPLEXITY_FAIL = 50
COMPLEXITY_WARN = 30

# Current grandfathered functions. Remove a line as each is split.
ALLOWED_LONG: set[str] = {
    "lib/core/routing/app_router.dart::createAppRouter",
    "lib/features/feed/presentation/viewmodels/for_you_view_model.dart::build",
    "lib/features/sports/presentation/widgets/sports_league_section.dart::build",
    "lib/core/widgets/ad_card.dart::build",
    "lib/features/article/presentation/widgets/article_action_bar.dart::build",
    "lib/core/theme/app_theme.dart::_build",
}
ALLOWED_COMPLEXITY: set[str] = set()

LIB = pathlib.Path("lib")
SKIP_PREFIXES = ("lib/l10n/",)
SKIP_STARTS = (
    "if ",
    "if(",
    "for ",
    "for(",
    "while ",
    "while(",
    "switch ",
    "switch(",
    "else",
    "try",
    "catch ",
    "return ",
    "class ",
    "base class ",
    "final class ",
    "sealed class ",
    "abstract class ",
    "enum ",
    "mixin ",
    "extension ",
    "typedef ",
    "@",
    "//",
)


def function_spans(path: pathlib.Path):
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    index = 0
    while index < len(lines):
        stripped = lines[index].strip()
        starts = (
            stripped.endswith("{")
            and "(" in stripped
            and "=>" not in stripped
            and not stripped.startswith(SKIP_STARTS)
        )
        if starts:
            depth = 0
            body: list[str] = []
            cursor = index
            opened = False
            while cursor < len(lines):
                segment = lines[cursor]
                body.append(segment)
                depth += segment.count("{") - segment.count("}")
                if "{" in segment:
                    opened = True
                if opened and depth <= 0:
                    break
                cursor += 1
            if opened:
                before_paren = stripped.split("(")[0].strip().split()
                name = before_paren[-1] if before_paren else "<constructor>"
                yield index + 1, name, body
                index = cursor
        index += 1


def measure(body: list[str]) -> tuple[int, int]:
    text = "\n".join(body)
    branches = len(
        re.findall(r"\b(if|for|while|case|catch)\b|&&|\|\||\?", text)
    )
    return len(body), branches


def main() -> int:
    errors: list[str] = []
    warnings: list[str] = []
    for path in sorted(LIB.rglob("*.dart")):
        relative = path.as_posix()
        if any(relative.startswith(prefix) for prefix in SKIP_PREFIXES):
            continue
        for line, name, body in function_spans(path):
            length, complexity = measure(body)
            key = f"{relative}::{name}"
            if length > LONG_FAIL:
                if key in ALLOWED_LONG:
                    warnings.append(
                        f"{relative}:{line} {name}: {length} lines (grandfathered)"
                    )
                else:
                    errors.append(
                        f"{relative}:{line} {name}: {length} lines exceeds "
                        f"{LONG_FAIL} (split it or add a reviewed exception)"
                    )
            elif length > LONG_WARN:
                warnings.append(f"{relative}:{line} {name}: {length} lines")

            if complexity > COMPLEXITY_FAIL:
                if key in ALLOWED_COMPLEXITY:
                    warnings.append(
                        f"{relative}:{line} {name}: complexity {complexity} "
                        "(grandfathered)"
                    )
                else:
                    errors.append(
                        f"{relative}:{line} {name}: complexity {complexity} "
                        f"exceeds {COMPLEXITY_FAIL} (extract branches)"
                    )
            elif complexity > COMPLEXITY_WARN:
                warnings.append(
                    f"{relative}:{line} {name}: complexity {complexity}"
                )

    print(
        f"Function structure: fail >{LONG_FAIL} lines / >{COMPLEXITY_FAIL} "
        f"branches; warn >{LONG_WARN} lines / >{COMPLEXITY_WARN} branches"
    )
    for warning in warnings[:40]:
        print(f"  warn {warning}")
    if len(warnings) > 40:
        print(f"  ... {len(warnings) - 40} more warnings")
    if errors:
        for error in errors:
            print(f"  FAIL {error}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
