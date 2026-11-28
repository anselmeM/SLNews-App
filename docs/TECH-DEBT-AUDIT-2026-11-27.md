# Technical debt audit — SLNews App

**Date:** 2026-11-27  
**Scope:** `SLNews-App` (Flutter Android/iOS working tree at `33c0d2b`).  
**Method:** source-size and complexity heuristics, duplicated-window scan, import
graph analysis, lcov coverage review, dependency inspection, CI/workflow review,
90-day churn analysis and a manual hotspot read. No SonarQube/Codecov service is
connected, so complexity and duplication numbers are ranked estimates rather
than certified metrics.

> Historical audits were marked superseded. The previous debt snapshot
> (`TECH-DEBT-AUDIT-2026-11-13`) included the web and scraper repos; this audit
> is app-only and reflects the post-Phase-3B-A codebase.

---

## 1. Executive summary

**Overall health: B (≈74/100 heuristic). Debt pressure: moderate, concentrated
in a small number of high-churn orchestration files, not in the module layout.**

| Dimension | Grade | Trend | Main driver |
|---|---:|---|---|
| Architecture | B | Flat/improving | Feature-first, zero import cycles; a few bootstrap/router/page hotspots |
| Code quality | C+ | Mixed | 9 functions >150 lines, max complexity 79, ~10% duplication |
| Testing | B | Improving | 907 tests, 79.43% coverage, strong gates; no CI goldens/device tests |
| Dependencies | B+ | Stable | 5 locked and 7 constrained versions, mostly deliberate |
| Documentation | C+ | Improving | 30 docs, but README and older audits were stale (fixed this pass) |
| Infrastructure | B+ | Improving | Strong CI/signing gates; R8 off, Android-only CI |
| Process/repo hygiene | C | Mixed | 94 branches, 259 commits/90 days, no explicit debt budget |

**Largest drags**

1. `JsonArticleMapper.map` — 112 lines, estimated cyclomatic score 79; the
   single highest-risk function in the app and on every ingestion path.
2. `AppBootstrap.create` — 253 lines, 0% measured coverage; startup, auth,
   storage and source wiring are one untested function.
3. `SettingsPage.build` — 290 lines; every new setting increases review and
   widget-test setup cost.
4. Presentation duplication — about **10.1%** of non-empty Dart lines are in
   duplicated 6-line windows; five catalogue/manage pages repeat the same
   scaffold/search/list structure.
5. Testing blind spots — `app_bootstrap`, `app.dart`, `clerk_auth_repository`,
   RSS/ESPN/league sources and `preferences_store` are far below the quality of
   the rest of the suite. Goldens and the single integration smoke test do not
   run in CI.
6. Process debt — 32 local + 62 remote-tracking branches; all feature branches
   remain after squash-merges.

**Quick wins completed in this pass**

- Fixed Sports news overflow menu: “Show less like this” now routes through the
  shared article-action handler instead of showing a snackbar and dropping the
  dismissal.
- Constrained popup-menu labels with `Flexible` + ellipsis, removing a real
  RenderFlex overflow (0.5–61 px) in the shared overflow menu.
- Added a regression test for the Sports dismiss path.
- Refreshed stale README claims (signing fallback, coverage floor, test
  commands, onboarding city picker).
- Marked the two older point-in-time audits as superseded and added this
  snapshot.

---

## 2. Inventory and metrics

| Metric | Current | Previous snapshot |
|---|---:|---:|
| `lib/` Dart files | **241** | 264 |
| `lib/` lines | **36,153** | ~45.4k (incl. generated/other) |
| Test Dart files / lines | **129 / 21,275** | — |
| Functional tests | **907 pass** | 750 (Nov 20) |
| Golden tests | **9** | 9 |
| Total line coverage | **79.43%** (floor 75.5%) | 80.06% (Nov 20) |
| Files >400 / >500 / >800 lines | **15 / 0 / 0** | 3 >500 (Nov 20) |
| Functions >60 / >100 / >150 lines | **65 / 25 / 9** | 209 >60 across 3 repos |
| Functions complexity-estimate >15 / >25 | **41 / 14** | — |
| Duplication estimate (6-line windows) | **10.1%** | ~16% across 3 repos |
| Import cycles | **0** | — |
| TODO/FIXME/HACK | **0** | 0 |
| Silent `catch (_)` | **57**, mostly documented best-effort fallbacks | — |
| Outdated dependencies | **5 locked older, 7 constrained older** | 55 app |
| Local / remote branches | **32 / 62** | — |
| Commits in last 90 days | **259** | — |
| Functional suite runtime (local, 4 workers) | **~3m45s** | ~7 min serial |
| CI gate runtime (test+coverage+APK) | **~6m45s** | — |

### File-size hotspots

| File | Lines | Note |
|---|---:|---|
| `lib/features/article/presentation/article_web_page.dart` | 496 | Native-reader fallback + WebView surface |
| `lib/core/providers/sync_controller.dart` | 488 | Sync state machine/retry boundaries |
| `lib/features/article/presentation/article_reader_body.dart` | 483 | Reader lifecycle, TTS, actions, scroll |
| `lib/features/settings/presentation/settings_page.dart` | 471 | 290-line build method |
| `lib/features/news/presentation/news_page.dart` | 469 | Category page composition |
| `lib/features/feed/presentation/widgets/weather_briefing_card_sections.dart` | 468 | Card variants |
| `lib/core/providers/personalization_profile.dart` | 456 | Profile persistence + events |
| `lib/core/utils/html_content.dart` | 452 | HTML renderer |
| `lib/features/sports/presentation/sports_page.dart` | 450 | Scoreboard/news/leagues composition |
| `lib/core/domain/personalization.dart` | 449 | Ranking engine + diversity/exploration |

The 500-line warning gate is currently clean. This is a good ratchet; do not
raise it to accommodate the next feature.

### Function hotspots

| Function | Lines | Complexity estimate | Risk |
|---|---:|---:|---|
| `JsonArticleMapper.map` (`json_article_mapper.dart:65`) | 112 | 79 | **High** — every feed source mapping |
| `Article.copyWith` (`article.dart:86`) | 38 | 48 | Low — mechanical, but 17 fields |
| `AppSettings.copyWith` (`app_settings.dart:99`) | 45 | 45 | Low — mechanical |
| `DefaultWeatherRepository._fetch` | 50 | 41 | Medium — consent/refresh races |
| `IndexQuoteSource.parseChart` | 41 | 41 | Medium — market payload shapes |
| `SportsPage.build` | 121 | 34 | Medium — page composition |
| `SyncController.collectLocalState` | 86 | 33 | Medium — merge correctness |
| `RssWire._mediaImage` | 36 | 33 | Medium — malformed feeds |
| `AppBootstrap.create` | 253 | 31 | **High** — startup/auth/storage path |
| `createAppRouter` | 241 | 30 | Medium — route graph review |
| `SettingsPage.build` | 290 | 28 | Medium — UI composition |
| `ForYouViewModel.build` | 171 | 23 | Medium — ranking orchestration |
| `FeedSlivers.build` | 229 | 21 | Medium — feed section composition |

### Duplication hotspots

Estimated **10.1% duplicated lines** (456 repeated 6-line windows). The largest
clusters are not domain bugs; they are repeated page scaffolding:

- five `manage_*` pages repeat scaffold, search field, catalogue list and empty
  state (`manage_sources`, `manage_topics`, `manage_sports`,
  `manage_league_teams`, `catalogue_list`);
- sports/league/team/publisher pages repeat page header, section-list padding
  and empty-state blocks;
- settings/following rows repeat the same chevron/list-tile structure.

Extracting a shared `CataloguePageScaffold`, `SearchHeader` and
`SectionListPadding` would remove the highest-volume duplication first.

### Architecture/coupling

- **No file-level import cycles** across 241 files.
- Feature-first boundaries are intact; domain models have no reverse dependency
  on presentation.
- High fan-out hubs: `app_bootstrap.dart` (33 imports), `app_providers.dart`
  (32), `sports_page.dart` (26), `for_you_page.dart` (26), `app_router.dart`
  (23). These are orchestration points, not violations, but they are the
  modules where change amplification is highest.
- `app_providers.dart` and `app_bootstrap.dart` still act as object-graph god
  modules. Extract construction phases from bootstrap; leave providers as the
  composition root.

### Testing debt

Strengths:

- 907 functional tests, 9 goldens, 79.43% line coverage.
- Per-file floors for API client, API source, offline repository, remote sync,
  sync state and push.
- New-file coverage floor (60% for added `lib/` files ≥40 lines).
- Format, analyze, generated-l10n, secret scan and release compile in CI.

Gaps (from `coverage/lcov.info`):

| Module | Coverage | Risk |
|---|---:|---|
| `app_bootstrap.dart` | **0%** (106 lines) | Startup failure cannot be caught by tests |
| `app.dart` | **0%** | App shell/theme lifecycle untested |
| `clerk_auth_repository.dart` | **0%** (55) | Auth adapter only manually tested |
| `sport_spotlight_card.dart` | **0%** (62) | Golden-only |
| `feed_source.dart` | **7.1%** | RSS/base feed abstraction |
| `espn_source.dart` | **13.1%** | Sports feed mapping |
| `league_news_source.dart` | **10.9%** | League news/aggregation |
| `preferences_store.dart` | **40.6%** | Persistence/box-closed fallbacks |
| `app_router.dart` | **53.5%** | Deep-link/navigation matrix |
| `push_service.dart` | **53.3%** | Floor exists but low |
| `article_web_page.dart` | **53%** | WebView fallback |

The `integration_test/app_smoke_test.dart` is 28 lines and is not part of any
CI workflow. Goldens are intentionally excluded from CI because host pixels
differ, which means visual regressions can merge unless someone runs them
locally before a release.

### Dependency debt

`flutter pub outdated --no-dev-dependencies` reports:

- **Locked older:** `flutter_local_notifications` 22.3.3 (23.0.4 available),
  `geolocator` 14.0.1 (14.1.2), `sentry_flutter` 10.4.0 (10.7.0), `xml` 7.0.1
  (7.1.0), `youtube_player_iframe` 6.0.3 (6.0.4).
- **Constrained older:** `clerk_flutter` beta, `xml` via
  `clerk_flutter → flutter_svg`, `flutter_local_notifications` major, and
  related platform packages.

These are documented constraints, not accidents. There is no app dependency
vulnerability gate: Dependabot opens upgrade PRs, but no `dart pub audit`/OSV
scan runs in CI. Given five constrained versions, adding vulnerability scanning
is more valuable than forcing major upgrades.

### Documentation debt

- 30 Markdown docs, plus architecture/state-machine/contract docs. Strong.
- The README was materially stale (release signing, coverage floor, test
  commands, onboarding city picker). Fixed in this pass.
- Two point-in-time audits (2026-11-13 and 2026-11-20) were presented as current.
  Marked superseded in this pass.
- No `docs/README.md` index; 30 files make discovery harder.
- `docs/FEATURE-GAPS.md` is a useful historical log but mixes “shipped” and
  “open” claims with an old baseline.

### Infrastructure/process debt

- CI is strong: pinned actions, secret scanning from the base branch, signed
  release guard, coverage/new-file/file-budget gates, release APK/AAB artifacts.
- **R8/minification and resource shrinking are off**, so the release is larger
  and less obfuscated; rules need validation before enabling.
- **iOS has no CI build/signing check**.
- **Goldens and integration smoke are not CI-enforced**.
- No startup/render performance baseline.
- **94 branches** remain. Squash merges make them look unmerged to git, but the
  PRs are merged; branch deletion on merge would stop the accumulation.
- Weekly dependency PRs auto-merge patch/minor; majors require migration. No
  explicit debt budget or monthly debt dashboard.
- Release upload to Play is still manual; AAB artifact exists.

---

## 3. Impact assessment

Assumptions: one engineer; savings are engineering hours, not currency, because
loaded team cost is not available. Effort includes tests and review.

| Debt | Interest paid now | Fix effort | Expected saving | Risk if ignored |
|---|---|---:|---:|---|
| `JsonArticleMapper.map` complexity | Every source change touches one 112-line branch-heavy function; feed regressions are broad | 12–16 h | 4–6 h/month | **High** — ingestion outage |
| `AppBootstrap.create` untested | Startup/auth/storage regressions only found manually | 10–14 h | 3–5 h/month | **High** — blank/crash first launch |
| Ingestion source coverage | ESPN/league/RSS paths fail silently to seed fallback | 16–24 h | 6–8 h/month | **High** — missing content |
| Settings build 290 lines | New setting touches 290-line tree; widget tests grow | 8–12 h | 2–3 h/month | Medium |
| Presentation duplication (10%) | UI policy changes copy-pasted across 5 pages | 10–14 h | 3–5 h/month | Medium |
| Goldens/integration not CI | Layout/native-flow regressions escape PRs | 12–16 h | 4–6 h/month | Medium |
| R8 off | Larger APK, no shrink/obfuscation | 8–12 h | Artifact/security hardening | Medium |
| Branch/doc hygiene | Review/onboarding friction | 3–5 h | 1–2 h/month | Low |
| Dependency lag | Planned migrations become urgent | 2 h/month | 4–6 h/quarter | Low–Medium |

**Risk ranking**

1. **High:** ingestion mapper + untested bootstrap/source modules.
2. **High:** native/device flows and goldens not gated in CI.
3. **Medium:** presentation duplication and large build methods.
4. **Medium:** R8 and iOS CI.
5. **Low:** branch names, docs index, dependency cadence.

---

## 4. Remediation roadmap

### Now — completed in this pass

| Action | Effort | Status |
|---|---:|---|
| Route Sports news overflow actions through shared handler | 1 h | **Done** |
| Fix popup menu text overflow | 30 min | **Done** |
| Add Sports dismiss regression test | 30 min | **Done** |
| Refresh README facts | 1 h | **Done** |
| Mark stale audits superseded + current snapshot | 2 h | **Done** |

**Exit:** no known action-dropping menu, no overflow assertion in the menu, docs
match the codebase.

### Next — 2–4 weeks

1. **Refactor `JsonArticleMapper.map`** into field helpers
   (`_identity`, `_link`, `_body`, `_publisher`, `_dates`) while keeping a
   mapping contract suite. Target function ≤40 lines and complexity <20.
   Effort 12–16 h.
2. **Extract `AppBootstrap.create` phases**: `_openStorage`,
   `_createIdentity`, `_buildSourceGraph`, `_buildRepositories`. Add tests with
   `allowPersistence: false` for fallback/anonymous/timeout branches. Add a
   per-file coverage floor at measured−2. Effort 10–14 h.
3. **Raise source coverage**: ESPN, league-news and FeedSource mapping tests;
   target at least 60% on each and add floors. Effort 16–24 h.
4. **CI goldens/integration**: run goldens in a pinned Linux container and add a
   nightly/emulator `integration_test` job. Effort 12–16 h.
5. **Branch/doc cleanup**: delete merged local/remote branches after PR merge;
   add a `docs/README.md` index. Effort 3–5 h.

### 30–60 days

6. Split `SettingsPage.build` into settings sections (notifications, news,
   appearance, privacy) with a section widget per group. Effort 8–12 h.
7. Extract shared catalogue scaffold/search/list/empty state from the five
   `manage_*` and catalogue pages. Effort 10–14 h.
8. Split `FeedSlivers.build` by feed section and `SportsPage.build` by stream.
   Effort 10–14 h.
9. Introduce a function-structure warning gate: warn >80 lines/>30 complexity,
   fail new functions >150/>50 with a documented allowlist for the current
   hotspots. Effort 4–6 h.
10. R8/shrinking with a ProGuard rules pass and device validation. Effort 8–12 h.

### 90 days

11. iOS build/signing CI cancellation and a device matrix (Android API 26/34/36,
    iPhone simulator build).
12. Startup/render performance baseline and budget.
13. Debt dashboard review monthly; target duplication <7%, coverage ≥82%,
    functions >150 lines ≤3, branches <10.
14. Dependency major migrations: local notifications 23, Sentry 10.7+, Clerk
    beta exit path. Each with its own PR and rollback.

---

## 5. Quick starts (copy/paste)

```bash
# Current gates
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/core test/contracts test/data test/features test/sync test/push test/security --coverage --concurrency=4
python scripts/check_app_coverage.py

# Structural hotspot report (same heuristics as this audit)
# See the command history in this session; no committed script yet.

# Branch hygiene (after confirming the PRs are merged)
git branch --merged origin/master
git remote prune origin
```

Suggested branch cleanup policy:

- enable “Automatically delete head branches” in GitHub;
- delete local branches after merge with `git branch -d`/`-D`;
- keep only active release/spike branches.

---

## 6. Prevention plan

### Automated quality gates

```yaml
existing:
  format: error
  analyze: error
  functional_tests: required
  coverage_total: "≥75.5%"
  coverage_new_file: "≥60%"
  critical_floors: 6 modules
  file_budget: "warn 500 / fail 800"
  secret_scan: required
  release_compile: required

add:
  function_budget:
    warn_over: 80 lines / 30 complexity
    fail_new_over: 150 lines / 50 complexity
    allowlist: current known hotspots only
  source_coverage_floors:
    - app_bootstrap.dart
    - feed_source.dart
    - espn_source.dart
    - league_news_source.dart
    - preferences_store.dart
    - app_router.dart
  golden_ci: pinned Linux renderer
  integration_smoke: emulator/nightly
  dependency_audit: dart pub audit or OSV on every dependency PR
  branch_delete_on_merge: true
```

### Process

- Reserve **20% of sprint capacity** for debt; publish the dashboard monthly.
- Every incident adds one regression test and one boundary fix.
- PR template: “Does this touch a hotspot? Coverage delta? New file budget?”
- Quarterly review of file/function exemptions; ratchet only downward.
- Do not bundle major dependency upgrades with feature work.
- Release checklist: goldens, integration smoke, R8 validation, signing.

### Success metrics (90 days)

| Metric | Current | Target |
|---|---:|---:|
| Total line coverage | 79.43% | **82%** |
| Files >500 lines | 0 | 0 |
| Functions >150 lines | 9 | **≤3** |
| Max complexity hotspot | 79 | **<40** |
| Duplication estimate | 10.1% | **<7%** |
| Integration/golden CI | absent | **required/nightly** |
| Branches (local+remote) | 94 | **<20** |
| Critical module floors | 6 | **12** |
| TODO/FIXME | 0 | 0 |

---

## 7. Communication summary

**For stakeholders**

- The app is not in a debt crisis: architecture is sound, gates are stronger
  than the previous audit, there are no TODO markers and no import cycles.
- The risk is concentrated: a complex ingestion mapper, untested startup and
  source modules, and native visual flows that CI cannot see.
- Recommended investment: **~90–120 engineering hours over the next quarter**,
  starting with mapper/bootstrap/source tests and presentation extraction.
- Expected payoff: fewer feed/startup regressions, faster settings/catalogue
  changes, safer releases, and a smaller/faster APK once R8 is validated.

**For developers**

- Keep the 500-line and new-file coverage gates.
- Do not add another 100-line `build()` or mapper branch; extract before adding.
- Any change to `json_article_mapper`, `app_bootstrap`, `feed_source`,
  `espn_source` or `league_news_source` needs a focused regression test.
- Run goldens and the integration smoke before a release; they are not in CI yet.

---

## 8. Limitations

- Complexity and duplication figures are heuristics over Dart text, not
  SonarQube/Codecov measurements.
- Coverage excludes generated l10n and is line-only (Flutter lcov has no branch
  data).
- The codebase is changing daily; re-run this audit after the next 2–3 large
  feature merges.
- No production telemetry exists for app-side crash/performance baselines, so
  impact estimates are engineering judgment rather than measured incident cost.
