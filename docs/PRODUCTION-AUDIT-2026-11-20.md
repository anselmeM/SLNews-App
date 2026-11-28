> **Superseded:** this is a historical point-in-time audit. For the current
> technical-debt snapshot see [TECH-DEBT-AUDIT-2026-11-27.md](TECH-DEBT-AUDIT-2026-11-27.md).

# Production code audit — 2026-11-20

**Scope:** `SLNews-App` (Flutter, Android + iOS targets) working tree, uncommitted.
**Method:** full gates, targeted static scans (secrets, dangerous APIs, WebView,
manifest, storage, dependency state), source-size/architecture review, and a
local release compile. This is an app-repo audit; the web and scraper repos were
covered by the 2026-11-13/14 audits and are referenced where they intersect.
**Overall grade:** **B+ / release-ready after operations and device QA.** No open
critical or high-severity application vulnerability was found.

---

## Executive summary

| Area | Grade | Evidence |
|---|---|---|
| Architecture | **B+** | Feature-first structure, explicit provider graph, test seams. 3 files exceed the 500-line warning. |
| Security | **A-** | Secret scan pass, no TODO/hardcoded credentials, strict manifest, token host allow-list, WebView link policy. Residual: R8 off, extractable client API key. |
| Performance | **B** | Lazy feeds, skeleton placeholder, image cache, 12-card video rail, split APKs. R8/minify intentionally off; no startup benchmark. |
| Testing | **B+** | **750 tests pass**; **80.06%** line coverage; critical floors pass. No integration/E2E or device tests. |
| Production readiness | **B** | Sentry, CI/CD, Dependabot, docs, hardened signing gates. Blocked by GitHub billing and Play/iOS operational tasks. |

**Critical issues:** 0 in application code.
**Release blockers:** GitHub Actions billing (all app CI fails at startup) and
unfinished Play Console/launch operations.
**Fixes applied during this audit:** 18 patch/minor dependency updates; debug-only
cleartext allowance for local sync (release remains cleartext-blocked).

---

## 1. Gates and verification

| Gate | Result |
|---|---|
| `dart format --set-exit-if-changed` | clean |
| `flutter analyze --no-pub` | **No issues found** |
| Full suite (`test/core test/data test/features test/sync test/push test/security`) | **750 passed** |
| Total line coverage | **80.06%** (floor 75.50%) |
| Critical per-file floors | all pass (`api_client` 85.71%, API source 94.16%, offline repo 93.25%, remote sync 91.55%, sync state 86.67%, push 54.73%) |
| New-file coverage floor | pass |
| Secret scan | pass (526 tracked files) |
| Localization freshness | `flutter gen-l10n` + `git diff --exit-code lib/l10n` clean |
| Release compile | `flutter build apk --release --split-per-abi` succeeded — 30.7 / 32.9 / 34.4 MB per ABI |
| Debug compile | succeeded; merged debug manifest confirms cleartext allowed in debug only |

> Device caveat: no Android device/emulator was attached, so the release APK was
> compiled but not smoke-tested. A release build without `key.properties` now
> fails unless `SLNEWS_ALLOW_DEBUG_SIGNED_RELEASE=true` is set explicitly; PR CI
> uses that opt-in only for a compile-validation artefact, and the
> protected-branch path refuses to build unsigned releases.

---

## 2. Architecture

- Feature-first layout (`lib/core`, `lib/features`) with domain/data/presentation
  separation, Riverpod providers, and injectable test seams is consistent across
  the app.
- No `TODO`/`FIXME`/`HACK` markers remain.
- All application logging routes through `AppLog` (debug-only `debugPrint` plus
  Sentry reporting in release); there is no stray `print`.
- File budget: 215 Dart source files / ~31k lines. **No file now exceeds the
  repo's 500-line warning** (hard limit 800): the three former offenders were
  split into provider/status/part modules (`app_providers.dart` 425,
  `sync_controller.dart` 460, `sports_league_section.dart` 385) and the
  league-look lookup was extracted to a directly tested file.

---

## 3. Security

**No open critical/high-severity issue.** Verified protections:

- Secret scan passes; no credentials, private keys or tokens in tracked files.
- Android manifest: `allowBackup=false`, `usesCleartextTraffic=false`,
  `fullBackupContent=false`, minimal permissions, deep links scoped to the
  article host; custom scheme filters cannot claim arbitrary URLs.
- Release signing: keystore secrets are only decoded on non-PR protected-branch
  builds; CI refuses to produce a release when the keystore secret is absent.
- Auth: Clerk session token is attached only to explicitly allow-listed hosts;
  a throwing token provider degrades to no token.
- WebView (article "Read original"): JavaScript is required for the publisher
  page, but the only JS bridge parses/clamps a float and exposes no native
  surface; navigation policy blocks `javascript:`/`data:`/`intent:`/`file:`
  schemes, keeps same-publisher HTTPS in-page, and opens everything else
  externally. HTTP source pages are opened in the browser, never in-app.
- Local storage is Hive, not encrypted; it holds articles, reading history and
  preferences, not credentials. Clerk owns session storage. This is an accepted
  residual risk: the OS app sandbox plus `allowBackup=false` provide the primary
  boundary, and encrypting these boxes would require a Keystore/Keychain key,
  migration of existing boxes, and a reinstall-on-key-loss story disproportionate
  to the data held. Revisit if the app ever stores tokens, health data or private
  messages locally.
- Dependency updates applied; 18 packages advanced on the minor/patch line.
  Remaining constrained versions are deliberate (`sentry_flutter` pinned,
  `xml` capped by `clerk_flutter`, `flutter_local_notifications` major 23 not
  adopted without migration).
- Maintenance warning: `flutter_tts` and `home_widget` still apply the Kotlin
  Gradle Plugin; future Flutter releases will require plugin upgrades. Track
  these before the next Flutter SDK bump.

Residual security risks:

1. **R8/ProGuard is disabled** (`isMinifyEnabled=false`, `isShrinkResources=false`).
   The code comment documents why (per-plugin rules need validation). This is a
   production hardening gap: no shrinking/obfuscation and larger artifacts.
2. **Optional static API key** (`SLNEWS_API_KEY`) is compiled into the APK when
   supplied. Client keys are extractable; the server must keep rate limits and
   the key should be rotated as part of release operations. Token-only mode is
   already supported.
3. **No app-integrity/Play Integrity attestation** for API calls; server-side
   rate limits are the current control.
4. **Debug builds allow cleartext** for the documented local sync smoke test.
   Release builds do not; the merged debug manifest was verified.

---

## 4. Performance and reliability

- League feeds load lazily per section near the viewport; followed leagues show
  a skeleton instead of shifting the page.
- Video rail fetches 50 items, interleaves sources and caps the rail at 12;
  bundled seed is sorted newest-first.
- Images use disk caching; fonts are tree-shaken in release.
- APK split-per-ABI reduces install size to ~31–34 MB per architecture.
- Push topics, sync retry ladder, digest patch retry/coalescing and stale-write
  guards are covered by tests.
- No startup/render benchmark exists, so performance claims are qualitative.

---

## 5. Testing

Strengths:

- 750 unit/widget/integration-style tests; 80.06% line coverage.
- Per-file floors for network client, API source, offline repository, remote
  sync, sync state and push; new-file floor prevents untested additions.
- Tests cover digest ordering/retry/account scoping, routing, auth gates,
  WebView link policy, manifest security, notifications and golden layouts.

Gaps:

- **No `integration_test/` suite and no on-device test run.** Platform views
  (native YouTube player) and real notification/deep-link flows remain manual.
- iOS target exists but has no CI build/signing verification.
- The native-player controls and selection predicate are now widget-tested, but
  the iframe/captions/fullscreen behavior needs a device pass.

---

## 6. Production readiness

Present: Sentry crash reporting, structured `AppLog`, CI format/analyze/test/
coverage/secret-scan/release-build gates, Dependabot, hardened workflows,
release/rollback docs, Play checklists, architecture and state-machine docs.

Blockers:

1. **GitHub Actions billing is unpaid**, so every `SLNews-App` workflow fails in
   seconds with “recent account payments have failed or your spending limit needs
   to be increased.” The protected `master` branch requires the APK check, so no
   PR can merge and no release can be cut until this is fixed.
2. **Play Console operations**: screenshots, domain/Clerk production, closed
   testing, content-rights decision, final `SLNEWS_API_KEY` rotation.
3. **R8/shrinking** should be enabled and validated on a device before the next
   store build.
4. **iOS** needs a build/signing/test pass if it ships in this release window.

---

## 7. Changes applied during this audit

1. `flutter pub upgrade` — 18 transitive/direct packages moved to current
   minor/patch versions available within existing constraints. Full suite and
   all coverage gates re-run and green.
2. Debug-only cleartext allowance in `android/app/src/debug/AndroidManifest.xml`
   for the documented `http://10.0.2.2:<port>` sync smoke test; release remains
   `usesCleartextTraffic=false`. Verified in the merged debug manifest.
3. Split the three >500-line files into cohesive modules; no file now trips the
   500-line warning. Extracted `LeagueLook` with direct branch tests (100%
   coverage).
4. Added actionable debug logging to TTS, reading-history and video-like
   persistence failures. Remaining silent catches are documented fallbacks for
   absent test/platform services, not error paths.
5. Release signing guard: a release task without a keystore fails unless
   `SLNEWS_ALLOW_DEBUG_SIGNED_RELEASE=true` is explicitly set. Debug builds are
   unaffected; CI's PR compile-validation step opts in, protected-branch builds
   never do.
6. This report.

No application code logic was changed without tests. The working tree remains
uncommitted because CI is blocked by billing.

---

## 8. Priority actions

| Priority | Action | Why |
|---|---|---|
| **P0** | Pay GitHub billing / restore Actions; rerun the release gate | Nothing can merge or ship until CI runs |
| **P0** | Finish Play Console, production Clerk/domain, screenshots, closed test | Launch operations |
| **P1** | Device QA: native video controls, notifications, deep links; publish internal build | Platform-only surfaces are untested |
| **P1** | Enable R8 + resource shrinking with a ProGuard file; validate on device | Security/size hardening |
| **P1** | Rotate `SLNEWS_API_KEY`, confirm server rate limits; prefer token-only release | Extractable client key |
| **P1** | Add an `integration_test` smoke suite (boot → feed → article → saved) | Protect the critical path |
| **P2** | iOS build/signing CI if iOS ships | Current CI is Android-only |
| **P2** | Split the three >500-line files | Maintainability |
| **P2** | Add analytics/remote config and finish localization/a11y strings | Product observability and reach |

**Assessment: B+.** The app code is production-grade in security, testing and
architecture for a 1.0 news reader. The remaining risks are deliberate
hardening items and operations, not open code defects. Do not ship the local
debug-signed artifacts; release from the protected-branch CI once billing is
restored.
