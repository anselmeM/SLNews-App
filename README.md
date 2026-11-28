# SLNews app — the Flutter product


A cross-platform (iOS + Android) news reader for Sierra Leonean news, built with
Flutter on a clean, offline-first architecture. The interface reproduces the
Samsung News reference layout: a persistent four-tab bar, a graded hero carousel
with overlaid headlines, compact feed cards with inline like/more actions, a live
scoreboard, and a follow/subscription tab.

| | |
| --- | --- |
| Framework | Flutter 3.47 (Dart 3.13), Material 3 |
| State | Riverpod 3 (`flutter_riverpod`) — MVVM view models |
| Routing | `go_router` 18 — `/for_you`, `/news`, `/sports`, `/following`, `/article/:id` |
| Ingest | RSS/Atom (`xml`), REST + GraphQL/JSON endpoints (`dio`) |
| Offline | Hive cache + preferences, bundled seed content, always renders |
| Platforms | Android (APK), iOS (Xcode project included) |

```
lib/
├── main.dart                     # boot: opens storage, installs provider overrides
├── app.dart                      # MaterialApp.router, themes, text-scale scope
├── core/
│   ├── domain/                   # entities + repository contracts (pure Dart)
│   ├── data/                     # sources (RSS/REST/JSON), Hive stores, repositories,
│   │                             #   auth adapter, sync client
│   ├── providers/                # Riverpod graph, controllers, bootstrap
│   ├── auth/                     # Clerk token seam (session for allow-listed hosts)
│   ├── push/                     # FCM registration, topic segments, tap routing
│   ├── observability/            # Sentry settings + error reporter
│   ├── config/                   # build-time defines and legal links
│   ├── theme/                    # colour, typography, spacing tokens, ThemeData
│   ├── routing/                  # go_router configuration + route names
│   ├── shell/                    # 4-tab bottom navigation shell
│   ├── widgets/                  # shared design-system widgets
│   └── utils/                    # HTML renderer, time formatting, stable ids
└── features/                     # one folder per screen family
    ├── feed/                     # For You: hero carousel + streams
    ├── news/                     # News: category pills + hero + grid
    ├── sports/                   # Sports: scoreboard, leagues, teams, standings
    ├── markets/                  # Stocks/index board (slid-up panel)
    ├── following/                # Following: alert history + subscriptions
    ├── article/                  # Reader: header, hero media, body, action bar
    ├── bookmarks/                # Saved stories (offline)
    ├── search/                   # Search v1
    ├── onboarding/               # First-run topic picker
    ├── auth/                     # Sign-in page + account screen
    ├── video/                    # Video moments reel
    └── settings/                 # Preferences, legal, deletion
```

Deeper detail: [documentation index](docs/README.md), [architecture](docs/ARCHITECTURE.md),
design tokens: [design system](docs/DESIGN_SYSTEM.md), frozen interfaces:
[contract](docs/CONTRACT.md).

## Getting started

```bash
flutter pub get
flutter run                     # pick a device, or -d windows / -d chrome
```

Requirements: Flutter 3.47+ and, for Android, JDK 17 plus the Android SDK.
`flutter doctor` should be green for the platform you target.

## Building a testable APK

```powershell
# Windows / PowerShell — analyze, test, build, checksum, copy to build/dist
# Works on Windows PowerShell 5.1 (what a stock Windows box has) and on 7.
powershell -NoProfile -File scripts/build_apk.ps1

# one APK per ABI instead of a single fat APK (~74 MiB)
powershell -NoProfile -File scripts/build_apk.ps1 -SplitPerAbi
```

```bash
# Linux / macOS / CI
./scripts/build_apk.sh
./scripts/build_apk.sh --split
```

Or directly:

```bash
flutter build apk --release            # build/app/outputs/flutter-apk/app-release.apk
flutter install --release              # sideload onto the attached device
```

`.github/workflows/build-apk.yml` runs the same gates and uploads the APK as a
build artifact.

### Release signing

`android/app/build.gradle.kts` reads `android/key.properties` (git-ignored).
A release build without a keystore now **fails** unless
`SLNEWS_ALLOW_DEBUG_SIGNED_RELEASE=true` is set explicitly for a local
compile-validation artifact. Never distribute that debug-signed APK. Copy
`android/key.properties.example` and generate a keystore before shipping:

```bash
keytool -genkeypair -v -keystore android/slnews-release.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias slnews \
  -dname "CN=SLNews, OU=Mobile, O=SLNews, L=Freetown, C=SL"
```

## iOS

```bash
flutter build ios --release --no-codesign   # or open ios/Runner.xcworkspace
```

## Data sources

`lib/core/data/seed/outlet_registry.dart` declares the ingest pipeline: Sierra
Leonean outlets (Awoko, Concord Times, Sierra Leone Telegraph, Politico SL,
Standard Times, Kallon's Newswire, Salone Times) plus wire services, each with a
`FeedSourceKind` (`rss`, `restJson`, `graphql`). Every entry documents whether
its URL is verified.

The **SLNews scraper API** (`SLNewsAPIScapper`, deployed on Render) is wired in as
a first-class aggregate source, and **Clerk** provides identity behind an
`AuthRepository` contract. Both are optional and off unless configured:
`CLERK_PUBLISHABLE_KEY` enables sign-in *and* the API (signed-in readers present a
session token, so the release build embeds no scraper key); a static
`SLNEWS_API_KEY` remains supported for keyed builds. See
[docs/INTEGRATIONS.md](docs/INTEGRATIONS.md).

Account-scoped sync of bookmarks, likes and follows is specified in
[docs/SYNC-API.md](docs/SYNC-API.md) and delivered by the PWA's
`/api/mobile/v1/sync`; the platform plan lives in
[docs/ROADMAP.md](docs/ROADMAP.md).

Offline behaviour is the default, not a fallback: reads resolve
memory → Hive cache → **bundled seed** → network, so a fresh install with no
connectivity still renders a complete Sierra Leonean feed.

## Testing

```bash
flutter analyze
flutter test test/core test/contracts test/data test/features test/sync test/push test/security --concurrency=4
flutter test test/golden --concurrency=1                    # screen renders
flutter test test/golden --update-goldens                   # regenerate renders
```

`test/golden/` boots the **real** app — real bootstrap, router, pages and
bundled seed content with in-memory storage, with every timestamp pinned to one
instant so renders are byte-comparable — and writes one PNG per screen
(`for_you`, `news`, `section`, `sports`, `following`, `article`, `saved`,
`settings`, `sections`). It is the visual regression harness for the reference
layout, and the clearest proof that the app renders with no connectivity at all.

CI runs the functional, contract and security suites, then
`scripts/check_function_structure.py` (function length/complexity ratchet) and
`scripts/check_app_coverage.py`, which enforces three gates in one place:
total line coverage ≥ 75.5 %, per-file floors on the critical modules (API
client, sync, offline repository, push) and an 800-line budget per file
(warned at 500). A separate new-file gate requires 60 % coverage for added
`lib/` files. Flutter's coverage output has no branch records, so those per-file
floors are what makes an untested critical module fail the build rather than hide
inside the total. A separate Windows `Visual regression` workflow runs the
goldens when UI/assets change; a `Integration smoke` workflow compiles the
device-smoke harness on every relevant PR. The device run itself remains a
release step (`flutter test integration_test -d <device>`).

Current technical-debt snapshot:
[`docs/TECH-DEBT-AUDIT-2026-11-27.md`](docs/TECH-DEBT-AUDIT-2026-11-27.md).

### Verified on this machine (2026-11-15)

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `dart format --set-exit-if-changed lib test` | 291 files, 0 changed |
| `flutter test test/core test/data test/features test/sync test/push --coverage` | 640 tests, all passed; **77.61 %** line coverage (gate 76 %) |
| `python scripts/check_app_coverage.py` | passes: per-file floors and the 800-line file budget |
| `flutter test test/golden` | 9 golden renders, all passed |
| `scripts/smoke_api.ps1` | health ok · unauthenticated `/v1/news` correctly 401 |
| Release APK, code 61 | `SLNews-1.0.0-61.apk`, 74.0 MiB fat APK |
| Release AAB, code 61 | `SLNews-1.0.0+61.aab`, 68.6 MiB (71,904,245 bytes), SHA-256 matches the checklist, `jarsigner -verify` passes |

Splitting per ABI (`scripts/build_apk.ps1 -SplitPerAbi`) produces one APK per ABI
instead of a single fat APK.

## Notes and limitations

- The bundled seed catalogue is realistic **sample** content for development and
  demos, not a live wire feed; per-URL verification status lives in the registry.
- Ad units are locally painted house creatives (labelled `Ad` with a disclosure),
  not a live ad-SDK integration.
- Push notifications: FCM delivery is wired end to end — permission flow, device
  registration/refresh, topic segments derived from follows and notification
  toggles (persisted and reconciled on restart), foreground display, and
  tap-to-article routing. Remaining: iOS APNs capability, separate channels per
  segment, quiet hours and in-app badge counts.
