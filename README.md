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
│   ├── data/                     # sources (RSS/REST/JSON), Hive stores, repositories
│   ├── providers/                # Riverpod graph, controllers, bootstrap
│   ├── theme/                    # colour, typography, spacing tokens, ThemeData
│   ├── routing/                  # go_router configuration + route names
│   ├── shell/                    # 4-tab bottom navigation shell
│   ├── widgets/                  # shared design-system widgets
│   └── utils/                    # HTML renderer, time formatting, stable ids
└── features/                     # one folder per screen family
    ├── feed/                     # For You: hero carousel + streams
    ├── news/                     # News: category pills + hero + grid
    ├── sports/                   # Sports: scoreboard + inline ad + followed teams
    ├── following/                # Following: alert history + subscriptions
    ├── article/                  # Reader: header, hero media, body, action bar
    └── bookmarks/                # Saved stories (offline)
```

Deeper detail: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) ·
design tokens: [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) ·
frozen interfaces: [`docs/CONTRACT.md`](docs/CONTRACT.md).

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

# one APK per ABI (~15 MB each instead of ~43 MB)
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
When it is absent the release build is signed with the **debug** key so you
always get an installable artifact; copy `android/key.properties.example` and
generate a keystore before shipping:

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
flutter test test/core test/data test/features   # unit + widget tests
flutter test test/golden                          # compare screen renders
flutter test test/golden --update-goldens         # regenerate screen renders
```

`test/golden/` boots the **real** app — real bootstrap, router, pages and
bundled seed content with in-memory storage, with every timestamp pinned to one
instant so renders are byte-comparable — and writes one PNG per screen
(`for_you`, `news`, `sports`, `following`, `article`, `saved`). It is the visual
regression harness for the reference layout, and the clearest proof that the app
renders with no connectivity at all.

CI still runs only the functional suites (`test/core test/data test/features`),
because pixel output depends on the host renderer.

### Verified on this machine

| Command | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test test/core test/data test/features` | 264 tests, all passed |
| `flutter test test/golden` | 6 renders, all passed |
| `flutter build apk --release` | `build/dist/SLNews-1.0.0-release.apk` (64.4 MB fat APK) |
| `scripts/smoke_api.ps1` | health ok · unauthenticated `/v1/news` correctly 401 |

Splitting per ABI (`scripts/build_apk.ps1 -SplitPerAbi`) produces ~20 MB APKs.

## Notes and limitations

- The bundled seed catalogue is realistic **sample** content for development and
  demos, not a live wire feed; per-URL verification status lives in the registry.
- Ad units are locally painted house creatives (labelled `Ad` with a disclosure),
  not a live ad-SDK integration.
- Push notifications: the alert data model, storage and history UI are in place;
  wiring a real FCM/APNs transport is outside this delivery.
