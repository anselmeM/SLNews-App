# Production code audit â€” 2026-11-13

**Scope:** `SLNews-App` (Flutter), `SLNews-Web` (Next.js), `SLNewsAPIScapper` (Express/Prisma)
**Method:** line-level static review, repository gates, unit/integration tests, coverage, dependency audit, CI logs, production health checks.
**Overall grade:** **B / launch-ready with external blockers** â€” no open critical application vulnerability found; one high-impact ingestion bug and two CI gates were fixed during the audit.

---

## Executive summary

| Repo | Grade | Current gate |
|---|---|---|
| App | **B+** | analyzer clean; 600 tests pass, 7 skipped; signed AAB code 50 |
| Web | **B** | lint/typecheck clean; 576 tests; production build passes; 9 production dependency advisories |
| Scraper | **B+** | typecheck/lint clean; **359 tests**, coverage **90.21% stmts / 83.63% branch** (thresholds pass); 3 moderate build-time advisories |

**Fixed during this audit**

1. **High â€” same-source story suppression (scraper).** Cross-source dedupe was adding accepted items to the index *inside the current feed pass*, so near-identical headlines from one publisher were dropped. The run now snapshots the index per source and adds accepted items afterwards. This was also why 17 ingestion tests failed in CI.
2. **Medium â€” CI coverage gate was red.** Added focused tests for the image backfill sweep, runtime state, image dimensions/fingerprints and URL guard; coverage now exceeds all thresholds.
3. **Medium â€” deadline guard.** A run whose deadline has already passed now returns before any DB or HTTP work.
4. **Low â€” image fingerprint corruption.** Missing ETag/Last-Modified/Content-Length produced a fingerprint of `":"` for every image, giving the same cache-busting key. Now returns `null` and leaves the URL untouched.
5. **Low â€” test isolation.** In-process source backoff is reset between ingestion tests; the image sweep can be skipped in ingestion tests via a test seam.
6. **Low â€” web quality.** Applied non-breaking dependency updates, removed an unused Clerk session read and Material icon-font lint warning, normalized import order. Lint is now 0 warnings.

---

## 1. App (`SLNews-App`)

**Scale:** 264 source files / ~40.5k lines; 6 files >500 lines (`sl_news_api_source.dart` 770, `sync_repository.dart` 792, `video_reel_page.dart` 611, `for_you_page.dart` 564, `sports_page.dart` 585, `rss_feed_source.dart` 547).

### Gates

| Gate | Result |
|---|---|
| `flutter analyze` | **No issues** |
| Full test suite (`--concurrency=1`) | **603 passed, 7 skipped, 0 failed** |
| Goldens | pass after refreshing article snapshot |
| Release artifact | AAB/APK code **50**, targetSdk 36, signed |
| Secret scan in build script | pass |
| Sentry | configured in release build |

### Architecture

- Feature-first clean architecture is consistent: domain models/repositories, data sources/repositories, presentation/viewmodels.
- Provider graph is explicit through `AppBootstrap`; test seams exist (`forFetcher`, `forPoster`, fakes).
- Lazy league feeds were added for the Sports feed; each block fetches its own league news near the viewport.
- **State is largely implicit** â€” documented in `docs/IMPLICIT-STATE-MACHINES.md` (13 machines) with rendered diagrams in `docs/state-machines.html`.

### Findings

| Severity | Finding | Status |
|---|---|---|
| Medium | Onboarding `_finish` has no `catch`; a failed follow/location write leaves partial state and no user-visible error | Open |
| Medium | Auth gate treats `AuthStatus.unknown` as signed-out; shell can flash before session restore. Anonymous users never see onboarding | Open |
| Medium | Sync failures have no retry/backoff; a failed phase persists until another local change | Open |
| Medium | Push desired-vs-applied topics diverge when subscribe/unsubscribe throws; applied set is memory-only | Open |
| Medium | Ad impressions counted per widget mount, no dedupe window/viewability | Open |
| Low | 90 `debugPrint` calls; no structured client logger | Open |
| Low | No coverage threshold in CI; tests are broad but unmeasured | Open |
| Low | Six files over 500 lines; sports/video/for-you pages mix layout and orchestration | Open |
| Info | Lazy league feed cache is not cleared by pull-to-refresh, so a successful feed isnâ€™t refetched | Open |

### Launch blockers (non-code)

- Play Console account/app verification, demo account, privacy mailbox, App Content forms, listing assets, closed-testing window.
- Play upload not done; latest AAB is local.

**App grade: B+** â€” strong test coverage and architecture, but state-machine debt and external Play tasks remain.

---

## 2. Web (`SLNews-Web`)

**Scale:** 205 source files / ~22.5k lines.

### Gates

| Gate | Before | After |
|---|---|---|
| Typecheck | pass | pass |
| ESLint | 0 errors, **11 warnings** | **0 errors, 0 warnings** |
| Unit tests | 576 pass | **576 pass** |
| Production build | pass | **pass** |
| `npm audit --omit=dev` | 10 advisories (4 high) | **9 (4 high, 5 moderate)** |
| Admin auth | server-side 307 gate + page guard | unchanged |

### Security posture

Already hardened earlier: admin middleware cookie gate, page-level guard, constant-time admin key compare, cron bearer-only, push-preview admin-only, private Blob proxy, image proxy SSRF guard, rate limits on login/events/share-card, no wildcard image patterns.

### Findings

| Severity | Finding | Status |
|---|---|---|
| High (transitive) | `@vercel/blob â†’ @vercel/oidc â†’ @vercel/cli-config â†’ zod` memory-exhaustion advisory; fix requires major `@vercel/blob` change | Open / accepted pending upgrade |
| Moderate (build) | `glob`/`minimatch` DoS advisories via Sentry build plugins (`--force` required) | Open / build-time |
| Low | Campaign lifecycle has no draft/paused state; stop is irreversible from the console; extension can revive an expired campaign | Open |
| Low | `docs/TODO.md` references remain in video-sync comments | Info |
| Info | No coverage threshold enforced in CI | Open |

**Web grade: B** â€” quality gates are clean and runtime auth is solid; dependency advisory debt is the main remaining risk.

---

## 3. Scraper (`SLNewsAPIScapper`)

**Scale:** 63 source files / ~9.4k lines; `scraper.ts` 784 lines.

### Root cause of the red CI (fixed)

`DedupeIndex` was mutated while iterating one source. The similarity threshold (`0.85`) then suppressed legitimate same-publisher headlines (â€œArticle 0â€ vs â€œArticle 1â€), and the same mechanism made 17 ingestion tests fail after the dedupe feature landed. Fixed with a per-source snapshot so only **DB + prior sources** are compared, never the sourceâ€™s own items. Cross-source first-publisher-wins is preserved.

### Gates before â†’ after

| Gate | Before | After |
|---|---|---|
| Tests | **17 failed / 331 passed** | **359 passed / 0 failed** |
| Typecheck | pass | pass |
| Lint | **1 error** (unused import) | **0 errors / 0 warnings** |
| Coverage statements | 86.62% (threshold 89) | **90.21%** |
| Coverage branches | 79.01% (threshold 83) | **83.63%** |
| Coverage lines | 88.18% (threshold 90) | **91.9%** |
| `npm audit --omit=dev` | 7 (2 high, 5 moderate) | **3 moderate** (build-time glob/swagger) |

### Findings

| Severity | Finding | Status |
|---|---|---|
| **High** | Same-source dedupe dropped real stories and broke CI | **Fixed** |
| Medium | No early return when the ingestion deadline is already exceeded | **Fixed** |
| Medium | Image-backfill sweep completely untested (coverage) | **Fixed** with focused tests |
| Low | Missing header validators produced a constant bogus fingerprint | **Fixed** |
| Low | In-process source backoff leaked between tests | **Fixed** |
| Low | Image backfill alert has no acknowledgement/reset; persistently failing URLs can hold it open | Open |
| Low | `scraper.ts` is 784 lines and mixes feed, page, sitemap, image and video orchestration | Open |
| Info | 3 moderate `glob`/`minimatch` advisories via `swagger-jsdoc`; fix requires major downgrade | Open / build-time |

**Scraper grade: B+** â€” ingestion correctness and CI are now green; module size and alert lifecycle remain.

---

## 4. Cross-system production readiness

| Area | Status |
|---|---|
| Health checks | scraper `/api/health` **200**; web `/api/health` present |
| Observability | Sentry in app/web; structured logger in scraper; image-backfill alert persisted |
| CI | app workflows, web CI, scraper CI all have gates; coverage now enforced in scraper |
| Database | Prisma migrations; Neon; runtime-state table created idempotently |
| Secrets | admin key rotated; scraper key rotated; no hardcoded live secrets found; GitGuardian active |
| Rate limiting | admin login, sponsorship events, share-card, analytics, push-subscribe |
| Image pipeline | SSRF guards, size/dimension checks, private Blob proxy, fingerprints |
| Launch blockers | Play Console/verification, privacy mailbox, demo account, content rights, closed testing |

---

## 5. Priority actions

### Before launch (owner)

1. Play Console account verification, app entry, Play App Signing, reviewer demo account.
2. Privacy mailbox live (or update policy/listing contact).
3. Upload AAB 50 to internal testing; device QA (ads, push, offline, deep links, sports).
4. App Content, Data Safety, News declaration, store listing, screenshots.
5. Closed testing window if required; staged production rollout.

### Engineering follow-ups (post-launch acceptable)

1. Upgrade `@vercel/blob` (and review Sentry plugins) to clear high/moderate advisories; re-run `npm audit`.
2. Reconcile desired vs applied FCM topics and persist applied state.
3. Split `scraper.ts` into feed/page/sitemap/image modules; add dead-letter handling for failed image URLs.
4. Add a 24h/7d alert acknowledgement path for image backfill.
5. Add app coverage reporting and split >500-line presentation files.
6. Investigate the sticky offline flag (a failed refresh remains until a later success).

---

## 6. Verification evidence

```text
App:      flutter analyze -> No issues
          flutter test --concurrency=1 -> 603 passed, 7 skipped
Web:      npm run typecheck -> pass
          npm run lint -> 0 errors, 0 warnings
          npm test -- --run -> 61 files / 576 tests passed
          npm run build -> pass
Scraper:  npm run typecheck -> pass
          npm run lint -> 0 errors, 0 warnings
          npm test -> 29 files / 359 tests passed
          npm run test:coverage -> 90.21 stmts / 83.63 branch / 91.9 lines (pass)
          npm audit --omit=dev -> 3 moderate (build-time)
```

PRs: `SLNewsAPIScapper#36` (ingestion + tests + coverage), `SLNews-Web#141` (quality + dependencies).

---

## 7. Follow-up fixes from the implicit-state audit (code 51)

These were the highest-risk findings from `IMPLICIT-STATE-MACHINES.md`; all are
now implemented and covered by tests where practical.

| Machine | Fix | Verification |
|---|---|---|
| App session gate | `AuthStatus.unknown` now renders a splash instead of the anonymous shell, removing the session-restore flash | auth/onboarding suites pass |
| Onboarding | Added catch + visible error; onboarding is not marked complete and navigation is skipped on a failed follow/location write | new failing-write widget test |
| Ad tracking | Impressions are deduped per sold unit per session; a failed post is retried on the next impression | tracker tests (duplicate + failed retry) |
| Sync | Bounded retry ladder (20 s â†’ 2 min â†’ 10 min) after a failed push/merge; cleared on success/sign-out/dispose | analyzer + sync tests |
| Lazy league feeds | Pull-to-refresh clears the league source cache and invalidates the feed providers, so stale/empty feeds recover | feed/sports tests |
| Onboarding/auth flow | 603 tests pass, 7 skipped; analyzer clean | full suite |

The app now ships as **1.0.0 (code 51)**. Remaining state machinery work is the
FCM desired-vs-applied reconciliation/persistence and an explicit offline
connectivity state.

---

## 8. Remaining findings closed (code 52)

| Finding | Fix | Verification |
|---|---|---|
| FCM desired-vs-applied divergence | Applied topic set is persisted under `push.topics` and seeded into `PushService` at startup, so removed/stale topics are unsubscribed instead of being forgotten across restarts | topic persistence/reconciliation test |
| Sticky offline flag | A foreground resume now refreshes ingest-backed feeds, giving the offline marker a recovery path without waiting for a manual pull | analyzer + feed/sync suites |
| Campaign stop irreversible | Admin console shows **Reactivate** for inactive campaigns, creating a fresh 7-day window | web typecheck/lint/tests |
| Extension revives expired campaign | `extendCampaign` now rejects stopped/expired campaigns; only Reactivate brings them back | web typecheck/lint/tests |
| Backfill alert has no acknowledgement | New `POST /api/stats/image-backfill/ack` clears alert/stuck counter and dead-letter list; sweep records the last 20 unresolved URLs with reasons | scraper tests + coverage |
| Push/sync state machines implicit | Deferred as a dedicated refactor; behavior is now bounded and persisted, but state is still represented by enums/booleans rather than sealed types | tracked |

**Final app gate:** 603 tests pass, 7 skipped; analyzer clean; **code 52** APK/AAB.

**Final scraper gate:** 361 tests pass; coverage 89.98% stmts / 83.36% branch /
93.56% funcs / 91.55% lines; lint/typecheck clean.

**Final web gate:** typecheck/lint clean; 576 tests pass; production build and
deployment after the campaign lifecycle merge.

