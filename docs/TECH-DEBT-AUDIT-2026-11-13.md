# Technical debt audit — SLNews (app, web, scraper)

**Date:** 2026-11-13  
**Scope:** `SLNews-App` (Flutter), `SLNews-Web` (Next.js), `SLNewsAPIScapper` (Express/Prisma)  
**Method:** source-size/complexity heuristics, duplication scan, dependency audits, coverage runs, test-suite timings and CI review.

> The duplication and long-function figures are machine estimates, not SonarQube
> verdicts. They are useful for ranking hotspots, not as precise KPIs.

---

## 1. Executive summary

**Overall debt pressure: 70/100 — moderate, concentrated in structure and dependency freshness.**

| Dimension | Score | Trend | Main driver |
|---|---:|---|---|
| Architecture | 62 | Flat | Large ingestion/API page and sync files |
| Code quality | 68 | Improving | 89 release-visible logs removed; unused imports pruned |
| Testing | 74 | Mixed | Scraper/web coverage gates; app has no coverage baseline |
| Dependencies | 58 | Improving | Web 4 high-severity transitive advisories remain |
| Documentation | 88 | Strong | Audits, state machines and launch checklists exist |
| Infrastructure | 76 | Improving | CI gates, Sentry, deployments, alert acknowledgement |

**Largest velocity drags**

1. `scraper.ts` (905 lines) contains ingestion, backfill, page and sitemap logic;
   `runSierraLeoneIngestion` alone is ~208 lines.
2. App `sync_repository.dart` (935) and `sl_news_api_source.dart` (863) are
   god files with mixed transport, mapping and policy.
3. Web `mobile-sync/engine.ts` (624) and `news-service.ts` mix query building,
   shaping and caching.
4. Web dependency advisories (4 high) require a planned `@vercel/blob` upgrade.
5. App has no measured coverage baseline, so 603 passing tests can hide
   uncovered critical paths.

**Quick wins delivered in this pass**

- Replaced 89 direct `debugPrint` calls across 34 files with a single
  `AppLog.debug` gate so release builds stay quiet.
- Removed 17 newly-unused `flutter/foundation` imports.
- Extracted the duplicated mobile `no-store` JSON responder from three routes
  into `src/lib/api/responses.ts`.
- Preserved all quality gates: analyzer clean, web lint/typecheck clean.

---

## 2. Inventory and metrics

| Metric | App | Web | Scraper |
|---|---:|---:|---:|
| Source files | 264 | 205 | 66 |
| Source lines | ~45.4k | ~25.3k | ~11.3k |
| Production files >500 lines | 6 | 2 + tests | 1 |
| Functions >60 lines (heuristic) | 209 | 73 | 41 |
| Duplication estimate (6-line windows) | ~16% | ~10% | ~10% |
| Direct debug logs | **0** (was 89) | 4 | 11 |
| TODO/FIXME/HACK | 0 | 0 real (2 doc references) | 0 |
| Tests | 603 pass / 7 skip | 576 pass | 361 pass |
| Coverage gate | none | 76/63/74/77 ratchet | 89.98/83.36/93.56/91.55 |
| Outdated dependencies | 42 locked, 11 constrained older | 33 | 21 |
| Production advisories | n/a | 9 (4 high) | 3 moderate |

### Code debt hotspots

| Hotspot | Evidence | Impact |
|---|---|---|
| `lib/core/domain/sync/sync_repository.dart` | 935 lines | Merge/push/pull/ledger policy in one unit; high regression surface |
| `lib/core/data/sources/sl_news_api_source.dart` | 863 lines | Transport + mapping + fallbacks + sports endpoints |
| `src/services/scraper.ts` | 905 lines; 208-line main function | Hard to test phases independently; review fatigue |
| `src/lib/mobile-sync/engine.ts` | 624 lines | Validation + apply + pull in one module |
| `src/lib/news-service.ts` | repeated article `findMany` blocks (5 sites) | Filter/order changes require synchronized edits |
| App scroll-to-top lifecycle | same controller/listener in 3 widgets | 3 places to fix scroll bugs |
| Scraper route validation | filter/pagination guard repeated across routes | Error-shape drift risk |
| Web route test mocks | Prisma mock factories repeated | Test maintenance tax |

### Architecture debt

- **App:** feature-first boundaries are good; the debt is file-level, not
  module-level. `sync_repository` and `sl_news_api_source` violate the
  "small, owned boundary" rule and make sealed-state adoption harder.
- **Web:** mobile-sync has a clean public contract, but the engine and
  news-service are aggregation points. Admin actions are now consistent, but
  server actions still mix auth, validation and persistence.
- **Scraper:** ingestion phases are implicit inside one function. Feed, sitemap,
  page-image and video orchestration should be separable units; observability
  is already a separate service.

### Testing debt

- Scraper has the strongest gate (coverage ratchet + 361 tests). Web has a
  ratchet and a large suite but browser e2e is separate. App has broad widget
  coverage and goldens but **no line/branch baseline or threshold**, so new
  untested code is invisible in CI.
- App suite runs ~7 minutes serially; acceptable locally, but slow feedback for
  a 600-test suite. Sharding by feature would cut PR latency.
- Long test files (e.g. 928/926 lines) mirror production hotspots and are
  candidates for fixture extraction.

### Dependency and security debt

| Risk | Count | Detail |
|---|---:|---|
| Web high advisories | 4 | `@vercel/blob → @vercel/oidc → @vercel/cli-config → zod`; fix is a major `@vercel/blob` upgrade |
| Web moderate | 5 | Sentry build plugins (`glob`/`minimatch`) |
| Scraper moderate | 3 | `glob`/`minimatch` via `swagger-jsdoc`; build-time |
| App freshness | 55 | 42 locked older, 11 constrained to older resolvable versions |
| Web freshness | 33 | Mostly minor/patch; majors need planned upgrades |
| Scraper freshness | 21 | Mostly minor/patch |

No critical vulnerabilities or committed secrets were found in the cleaned
repositories.

### Documentation debt

Low. Audits, state machines, launch checklists, API contracts and deployment
notes exist. The remaining gap is **architecture documentation for the large
sync/ingestion modules** — their boundaries live only in code comments.

### Infrastructure debt

- Web and scraper deploy from merged master; app release is a script plus manual
  Play upload.
- No app coverage artifact; no automatic dependency-upgrade cadence.
- Scraper image-backfill alerts now support acknowledgement/dead letters.
- Play Console/legal launch items are external blockers, not code debt.

---

## 3. Impact assessment

Assumptions: one engineer-hour; savings are rough engineering hours, not
currency, because team cost is not known.

| Debt | Interest paid now | Fix effort | Expected saving |
|---|---:|---:|---:|
| Web high advisories | Security review + upgrade planning each release | 16–24 h | 4–6 h/month of risk review; removes high-severity exposure |
| Scraper god function | Every ingestion change touches 1 file/1 function; incident triage slower | 20–28 h | 8–12 h/month |
| App sync/API god files | Sync bugs span 900-line files; high review cost | 32–40 h | 10–15 h/month |
| App no coverage baseline | Unknown regressions; manual QA catches gaps | 12–16 h | 6–10 h/month |
| Web repeated query builders | Filter changes implemented 3–5 times | 10–14 h | 4–6 h/month |
| App 3× scroll lifecycle | Scroll bugs fixed in 3 places | 6–8 h | 2–3 h/month |
| Sealed push/sync state | Implicit transitions still need reasoning in review | 24–32 h | 6–10 h/month |

**Risk ranking**

1. **High:** web `@vercel/blob`/`zod` advisories.
2. **High:** app sync/API god files (correctness risk during launch hardening).
3. **Medium:** scraper ingestion monolith (incident response).
4. **Medium:** app coverage blind spot.
5. **Low:** duplicated route guards/query builders and scroll lifecycle.

---

## 4. Prioritized remediation roadmap

### Now — this sprint (quick wins)

| Action | Effort | Status |
|---|---:|---|
| Centralize app debug logging behind `AppLog` (release-safe) | 4 h | **Done** |
| Remove unused foundation imports | 1 h | **Done** |
| Extract shared mobile no-store JSON responder | 2 h | **Done** |
| Add tech-debt report + remediation budget to docs | 2 h | **Done** |

**Exit:** no release-visible debug logging, no duplicate JSON cache policy,
baseline debt dashboard committed.

### Next — 2–4 weeks

1. **Upgrade `@vercel/blob`** and re-audit Sentry plugins; remove 4 high
   advisories. Effort 16–24 h. Do not use `--force` blind: pin, test uploads,
   image proxy and mobile contracts.
2. **Add app coverage baseline + threshold** (start at measured −1 point) and
   publish lcov. Effort 12–16 h. Highest ROI testing action.
3. **Split `scraper.ts`** into `ingestion/feed`, `ingestion/article`,
   `ingestion/sitemap`, `backfill` and keep `runSierraLeoneIngestion` as
   orchestration; target <120 lines per phase. Effort 20–28 h.
4. **Extract app scroll-to-top mixin/controller** used by scaffold, reader and
   top-stories pages. Effort 6–8 h.

### 30–60 days

5. Split `sync_repository.dart` and `sl_news_api_source.dart` by responsibility
   (transport, mapping, policy, sports client). Effort 32–40 h.
6. Extract web article query builder in `news-service.ts`; move shared admin
   action auth/validation helpers. Effort 10–14 h.
7. Split `mobile-sync/engine.ts` into validation / apply / pull units with
   contract tests. Effort 16–24 h.
8. Add web dependency cadence: monthly minor/patch, quarterly major review.

### 90 days

9. Explicit sealed types for push and sync state machines, replacing
   enum+boolean combinations. Effort 24–32 h.
10. Split app presentation god files (video reel, sports, for-you) into
    section widgets; target <400 lines. Effort 40–60 h.
11. Raise web coverage to 80% statements / 68% branches; app to 60% statements
    with critical-path exceptions documented.

---

## 5. Prevention plan

### Automated gates

```yaml
file_budget:
  warn_over: 500 lines
  fail_over: 800 lines
  exemptions: sync_repository.dart, sl_news_api_source.dart, scraper.ts
  ratchet: reduce exemption list by one file per quarter

function_budget:
  warn_over: 60 lines
  fail_over: 120 lines
  exemptions: runSierraLeoneIngestion, backfillImages

quality_gates:
  app: analyze + tests + coverage ratchet (new)
  web: typecheck + lint + tests + coverage ratchet (exists)
  scraper: typecheck + lint + tests + coverage ratchet (exists)

dependency_gate:
  high/critical: block release
  moderate: documented exception with owner and review date
```

### Process

- 20% of each sprint reserved for debt; publish the same dashboard monthly.
- PR template asks: new debt introduced? hotspot touched? coverage delta?
- Every incident writes one prevention test and one boundary fix.
- Dependency review monthly; major upgrades scheduled, never bundled with
  feature work.
- Large-file exemptions are explicit and shrink each quarter.

### Success metrics (90 days)

| Metric | Current | Target |
|---|---:|---:|
| Overall debt score | 70 | 80 |
| Production files >800 lines | 3 | 1 |
| Functions >120 lines | 3+ | 1 |
| Direct release debug logs | 0 | 0 (hold) |
| App coverage gate | none | statements ≥60% |
| Web high advisories | 4 | 0 |
| Scraper coverage | 89.98/83.36 | hold or improve |
| Duplication estimate | 16/10/10% | ≤12/8/8% |

---

## 6. Verification

```text
App:      flutter analyze -> No issues
          flutter test --concurrency=1 -> 603 passed, 7 skipped
          direct debugPrint in lib -> 0 (AppLog.debug only)
Web:      npm run typecheck -> pass
          npm run lint -> 0 errors / 0 warnings
          npm test -- --run -> 576 passed
Scraper:  npm run typecheck -> pass
          npm run lint -> 0 errors / 0 warnings
          npm test -> 361 passed
          coverage -> 89.98 stmts / 83.36 branch / 93.56 funcs / 91.55 lines
```

**Quick-win commits:** app `f74ce64` (AppLog + report) and `8d72f80`
(functional fixes); web `d678381` / PR #143 (`noStoreJson` extraction);
scraper/deploy baseline at `36efcc0`. Code 53 artifacts carry the logging
cleanup. See `archive/PRODUCTION-AUDIT-2026-11-13.md` for the functional remediation
history.

---

## 7. Execution update — priority 1 and 2 completed

**Revised overall debt pressure: 75/100** (dependencies 58 → 84, testing
74 → 82).

### Priority 1 — production advisories: cleared

`npm audit --omit=dev` is now **0 vulnerabilities** (was 9: 4 high, 5 moderate).
No `@vercel/blob` downgrade was needed; package `overrides` resolve the
transitive chains:

```json
{
  "@vercel/cli-config": "^0.4.0",
  "glob": "^14.0.3"
}
```

- `@vercel/cli-config@0.4.0` requires zod `^4.6.6`, clearing the high-severity
  memory-exhaustion advisory while keeping `@vercel/blob@2.9.0`.
- `glob@14.0.6` brings patched `minimatch`, clearing the two Sentry build-plugin
  moderates.
- Verified: typecheck, lint, **576 tests**, production build. E2E runs in CI.
- Remaining `npm audit` (including dev): 10 moderate advisories in
  `vitest@4.1.10`/`typescript-eslint`; these are development-tool only and
  require toolchain upgrades, not runtime exposure.

### Priority 2 — app coverage ratchet: added

- Measured baseline on 2026-11-13: **76.45% line coverage** (`LF 10,127`,
  `LH 7,742`; full suite).
- Added `scripts/check_app_coverage.py`; minimum is **74.0%** (≈1.5 points below the CI-equivalent
  75.45%). CI prints the measured value and fails on regression.
- The APK workflow (`build-apk.yml`) now runs
  `flutter test … --coverage --concurrency=4` and execute the gate before the
  golden step.
- The local CI-equivalent command was re-run to confirm the same threshold
  passes without the golden files.

### Revised next actions

1. Split app sync/API god files (priority 4).
2. Sealed push/sync state types (priority 6).
3. Plan the dev-toolchain upgrades for the remaining 10 moderate dev advisories.

---

## 8. Priority 3 completed — scraper ingestion split

PR `SLNewsAPIScapper#38` (merged as `2efd715`) decomposes the 905-line
`scraper.ts` into bounded phase modules behind a stable facade:

| Module | Lines | Responsibility |
|---|---:|---|
| `scraper.ts` | 19 | Public facade/re-exports only |
| `ingestion/run.ts` | 60 | Deadline, shared budgets, phase orchestration |
| `ingestion/feed.ts` | 236 | RSS pass, dedupe, metadata/content backfill |
| `ingestion/backfill.ts` | 173 | Image sweep + missing-content repair |
| `ingestion/sitemap.ts` | 191 | Telegraph sitemap fallback |
| `ingestion/content.ts` | 282 | HTML/image/content helpers |
| `ingestion/types.ts` | 56 | Phase contracts |

- `runSierraLeoneIngestion` is now **42 lines** (was ~208).
- Largest phase function is `backfillImages` at **83 lines** (target <120).
- Largest phase file is 282 lines (was 905).
- Public imports (`firstPageImage`, `backfillImages`, `parseSitemapUrls`,
  `runSierraLeoneIngestion`, video re-export) are unchanged.
- Verified: typecheck, lint, **361 tests**, coverage **89.94/83.21/93.83/91.48**
  (all thresholds pass). Render redeploy triggered by the merge.

**Revised overall debt pressure: 80/100** (architecture 62 → 74).
Remaining highest-value structural work is the app sync/API split (priority 4).


---

## 9. Priority 5 completed — shared query + scroll lifecycle

**Web (PR #146):** every feed/search query repeated the same published /
relations / `publishedAt` order / skip / take block. Added
`src/lib/article-query.ts` with `findArticlePage()`; `news-service.ts` dropped
from 413 to ~375 lines. Behaviour unchanged (same where/order/include/skip/take),
verified by 576 tests, typecheck and lint.

**App:** added `ScrollToTopStateMixin` and replaced the three copied
scroll-controller/listener/dispose blocks in `SlPageScaffold`, the article reader
and the top-stories section page. The article reader still tracks reading
progress; the other two keep the simple visibility rule. Verified by analyzer
and the article/feed/golden suites (80 tests).

Remaining roadmap: app sync/API split (priority 4), sealed push/sync state types
(priority 6), and the dev-toolchain advisories.


---

## 10. Priority 4 completed — app sync/API split

**Sync domain:** `sync_repository.dart` was a 935-line mixed model file. It is now
a 155-line facade/library entry with five part files:
`sync_bookmark.dart` (140), `sync_reaction.dart` (73), `sync_follow.dart` (86),
`sync_state.dart` (232) and `sync_result.dart` (260). `part` files keep the
wire serialization, timestamp helpers and private parsers library-scoped, so
there is no behaviour change and no public import churn.

**Scraper API source:** `sl_news_api_source.dart` (871 lines) is now:
- `sl_news_api_source.dart` — 368-line transport/source class
- `sl_news_api_config.dart` — 178-line config + page value objects
- `sl_news_api_mapping.dart` — 332-line wire-to-domain mapping/policy

Public types remain importable from the original `sl_news_api_source.dart` path.

Verified locally: analyzer clean; split sync/API tests (150 tests) pass. CI runs
the full suite + coverage gate.


---

## 11. Priority 6 completed — sealed push/sync state

**Sync:** replaced the `SyncPhase` enum + nullable-field `SyncStatus` with a
sealed hierarchy:

- `SyncDisabled`, `SyncIdle`, `SyncSyncing`, `SyncSynced`, `SyncFailed`
- `SyncFailed` requires a typed `SyncFailure`; `SyncSynced` owns its server
  clock. Impossible combinations (failed without a reason, synced without a
  clock, syncing with a stale failure) can no longer be constructed.
- `SyncStatus.asSyncing()` carries last-run metadata into the in-flight state;
  the controller and account card now use pattern tests (`is SyncIdle`,
  `is SyncFailed`, `is! SyncDisabled`) instead of enum comparisons.

**Push:** added a sealed `PushStatus` hierarchy (`PushUnavailable`,
`PushPermissionDenied`, `PushDisabled`, `PushRegistered`, `PushFailed`) and
made `PushService.status` report the real transitions. The bool-returning
`enable()` API is unchanged for callers.

Verified: analyzer clean; sync/push/auth suites **123 tests pass**. CI runs the
full suite and coverage ratchet. This closes the implicit-state roadmap item.


---

## 12. Dev dependency advisories cleared

Web PR #147 upgrades `vitest` and `@vitest/coverage-v8` to **4.1.12** (patched)
and adds a targeted override for `minimatch ^11.0.1` under
`@typescript-eslint/typescript-estree`.

`npm audit` is now **0 vulnerabilities including dev** (was 10 moderate; the
production audit has been 0 since the earlier overrides). Verified with
typecheck, lint, **576 tests**, production build and CI (including e2e).

---

## 13. Priority 7 completed — file budget and coverage floors

Closed the two remaining structural items from section 3: oversized presentation
files, and a coverage gate that could not see a regression inside one module.

**Splits** (no behaviour change; every line was moved by line-range extraction,
so bodies stay byte-identical):

| File | Before | After | New files |
| --- | ---: | ---: | --- |
| `features/video/presentation/video_reel_page.dart` | 660 | 243 | `reel_widgets.dart` (345), `web_video_player.dart` (77) |
| `features/sports/presentation/sports_page.dart` | 603 | 444 | `sports_sections.dart` (161) |
| `features/feed/presentation/for_you_page.dart` | 591 | 156 | `feed_slivers.dart` (438) |
| `core/data/sources/rss_feed_source.dart` | 599 | 211 | `rss_wire.dart` (383) |

The widget splits use `part` / `part of`, so private class names and the public
API are unchanged. `RssParser`'s private static helpers became top-level private
functions in a part file, leaving every call site untouched. Sports deliberately
did **not** extract its `content` subtree: the page wraps the body in a dark
`Theme` and the notice/ad builders read the context above it, so moving them
into a child widget would have flipped those colours from the light shell theme
to dark.

**Gate.** `scripts/check_app_coverage.py` now enforces:

- total line coverage ≥ 76 % (measured 77.61 %);
- per-file floors on the critical modules: `api_client` 83, `sl_news_api_source`
  92, `offline_first_article_repository` 91, `remote_sync_source` 89,
  `sync_state` 83, `push_service` 48;
- file budget: fail over 800 lines, warn over 500.

There is no branch threshold because **Flutter 3.47's lcov output carries no
`BRDA` or `FNF`/`FNH` records** — verified against this suite's own output — so a
branch percentage cannot be computed from it. The per-file floors are the
substitute, and the script says so in its docstring rather than inventing a
number. CI also runs `test/push` in the coverage step now; excluding it is why
`push_service` used to measure ~4 % and any push regression was invisible.

**Remaining:** `lib/core/providers/sync_controller.dart` (545 lines) still trips
the 500-line warning. It is a controller rather than a page, and splitting it
means moving live state, so it stays warned (visible in every CI run) rather
than exempted.

**Verification:** format gate clean (284 files), `flutter analyze` clean,
**640 tests** pass, **9 goldens** pass, and the gate exits 0 on the real numbers
and 1 when the total floor is temporarily raised.
