# Integrations

Two external systems belong to the SLNews platform: the **scraper API**
(`SLNewsAPIScapper`, content) and **Clerk** (identity). This document records
what is wired up, what is deliberately not, and how to verify each one.

## 1. SLNews scraper API (content)

### Contract (verified against the deployed service)

Base URL: `https://slnewsapiscapper.onrender.com` (Render web service
`sl-news-api` + hourly cron `sl-news-scraper`).

| Endpoint | Auth | Notes |
| --- | --- | --- |
| `GET /api/health` | none | `{status, database, timestamp}`; unthrottled |
| `GET /v1/news` | `Authorization: Bearer <API_KEY>` | **primary**: `{data:[…], meta:{page,page_size,total,has_more}}` |
| `GET /api/news` | bearer | fallback: bare array + `X-Total-Count` header |
| `GET /api/news/:id` | bearer | single raw row (full text lives only here) |
| `GET /api/videos`, `/api/stats` | bearer | not consumed by the app |

`/v1` is the deliberate commercial contract: metadata + summary only
(`id, title, summary, source, category[], url, published_at`). Article bodies are
never exposed there, and **SLNews Mobile does not ingest them** — the reader
shows the summary and offers "Open in browser" to the publisher. That keeps the
mobile client inside the same licence boundary as paying API customers.

### How the app consumes it

`SlNewsApiSource` (`lib/core/data/sources/sl_news_api_source.dart`) implements the
existing `FeedSource` contract, so it plugs into the offline-first pipeline
without special cases: it is one more source that
`OfflineFirstArticleRepository` merges, de-duplicates by id, caches in Hive and
falls back from when the network is unavailable.

- Article ids are namespaced `slnews-api:<row id>` so scraper rows can never
  collide with RSS ids (which are hashes of canonical URLs).
- Requests go through `ApiClient`, which attaches `Authorization: Bearer <key>`
  from `defaultHeaders` and can additionally attach a per-request session token
  (`authTokenProvider`) once the reader signs in.
- **Disabled without a key.** `SlNewsApiConfig.isConfigured` is false when
  `SLNEWS_API_KEY` is empty, in which case the source issues no HTTP at all and
  the app serves RSS + bundled seed content exactly as before.

### Configuration

Nothing is hard-coded or committed. Values come from `--dart-define` (or a local,
git-ignored `.env.local` used by the helper scripts):

```powershell
flutter run `
  --dart-define=SLNEWS_API_KEY=$env:SLNEWS_API_KEY
```

```powershell
# release build with the API enabled
.\scripts\build_apk.ps1 -DartDefine @('SLNEWS_API_KEY=...', 'CLERK_PUBLISHABLE_KEY=pk_...')
```

| Name | Default | Purpose |
| --- | --- | --- |
| `SLNEWS_API_URL` | the Render host | base URL, for a self-hosted instance |
| `SLNEWS_API_KEY` | empty (**feature off**) | bearer key; lives in Render's `API_KEY` env var |
| `SLNEWS_API_PAGE_SIZE` | `20` | page size (1–100) |
| `CLERK_PUBLISHABLE_KEY` | empty (**auth off**) | Clerk publishable key |

### Security note

A static bearer key embedded in a mobile binary is extractable. That is an
acceptable trade-off while the key only gates *public* headline metadata, but if
the API is ever monetised the mobile client should exchange a Clerk JWT for a
short-lived token through a backend that holds the real key, or the scraper
should verify Clerk JWTs directly.

### Verifying it

```powershell
.\scripts\smoke_api.ps1                       # reads .env.local or $env:SLNEWS_API_KEY
.\scripts\smoke_api.ps1 -Key <key>            # one-off, key not echoed
```

Observed on this machine (no key configured):

```
[1/3] GET /api/health (no auth)          ok: status=ok database=connected
[2/3] GET /v1/news without a key         ok: unauthenticated request rejected
[3/3] authenticated /v1/news             skipped: no API key available
```

## 2. Clerk (identity)

### Why the app did not simply "add auth"

The app was anonymous and device-local by design: bookmarks, likes and follows
live in Hive. Clerk's value is not gating content (the scraper serves public
news) — it is letting a reader use **the same account as the web app**, so saved
stories, reactions, comments and push subscriptions follow them. That makes this
a data-ownership change, not just a login screen.

### What is implemented

| Layer | File | Role |
| --- | --- | --- |
| Contract | `lib/core/domain/auth/auth_repository.dart` | `AuthStatus`, `AuthUser`, `AuthState`, `AuthRepository` — pure Dart, no SDK types |
| Wiring | `lib/core/providers/auth_providers.dart` | `authRepositoryProvider`, `authControllerProvider`, `signInSurfaceProvider`, `SignInSurface` |
| UI | `lib/features/auth/presentation/` | `SignInPage` (`/sign_in`) and `AccountCard` (top of the Following tab) |
| Adapter | `lib/core/data/auth/clerk_auth_repository.dart` | the only file that imports the Clerk SDK |

The beta SDK is quarantined behind two seams: `AuthRepository` for session state
and `SignInSurface` for the provider's own widgets. Feature code imports neither
`clerk_flutter` nor `clerk_auth`, so replacing the SDK — or dropping it — is a
one-file change.

### Choosing a Clerk path

`clerk_flutter` (pub.dev, currently `0.0.18-beta`) is **community-maintained and
explicitly "provided as-is — not officially supported by Clerk"**, with breaking
changes expected before 1.0. It requires Flutter ≥ 3.27.4 (this project is on
3.47.7) and pulls in `webview_flutter`, `passkeys`, `image_picker`,
`phone_input` and `flutter_svg`.

Two ways forward, both behind the same contract:

1. **`clerk_flutter` (chosen)** — fastest to a working native sign-in with the
   existing publishable key; beta risk is contained by the seams above.
2. **Bring-your-own Frontend API client** — sign-in via Clerk's FAPI
   (email code / password / OAuth PKCE), session JWT in secure storage. No beta
   dependency, but the session lifecycle becomes code we own.

### Backend

Two independent decisions, neither required for the app to work today:

- **Scraper**: replace the static `API_KEY` with Clerk JWT verification
  (`@clerk/express` `clerkMiddleware()` + `getAuth(req)`), so mobile and web
  present the same credentials.
- **PWA**: its `/api/*` routes already use `auth()` and its user-scoped data
  (bookmarks, reactions, comments, push subscriptions) is what the mobile app
  would sync against — that is the next slice of work, and it needs the PWA's
  data model to be reachable from a mobile client (either the PWA routes or a
  shared backend service).

### Not done yet (explicitly out of scope for this pass)

- User-scoped sync: bookmarks/follows are still device-local. The migration
  needs a merge-on-first-sign-in rule and a backend that accepts the JWT.
- Production Clerk instance: `SLNews` already documents the rollout in
  `docs/CLERK-PRODUCTION-SETUP.md` (live keys, `clerk.slnews.sl` CNAME, optional
  `frontendApiProxy`). This app only needs the matching publishable key.

## 3. Mobile sync API (reader state)

Bookmarks, likes and follows sync to the reader's Clerk account through the PWA's
`/api/mobile/v1/sync` so they survive a reinstall and follow the reader between
devices. The contract is [SYNC-API.md](SYNC-API.md); the platform plan is
[ROADMAP.md](ROADMAP.md).

| Piece | Where |
| --- | --- |
| Contract | `docs/SYNC-API.md` (this repo, frozen) |
| Backend | `SLNews` — `src/app/api/mobile/v1/sync/route.ts`, `src/lib/mobile-sync/` |
| Tables | `MobileBookmark`, `MobileReaction`, `MobileFollow` (Neon, applied) |
| Client | `lib/core/data/sync/`, contract in `lib/core/domain/sync/` |
| Server notes | `SLNews/docs/mobile-sync-api.md` |

Why its own tables: the PWA's `SavedArticle` points at a PWA `Article` row, while
mobile items are external ids (`slnews-api:4821`, `rss:<hash>`) with no PWA row to
reference. Sync rows are therefore user-scoped snapshots keyed by the mobile item
id — no change to the existing web tables, and `sourceUrl` is already carried for
the later reconciliation in roadmap phase 5.

Configuration: `--dart-define=SLNEWS_SYNC_URL=<origin>`. The default is the live
Vercel origin **`https://sl-news.vercel.app`** — verified 2026-10-16: `/api/health`
returns `healthy` and `/api/mobile/v1/sync` answers `401 {"error":"Unauthorized"}`
for anonymous GET and POST. The intended public domain `slnews.sl` does **not**
resolve yet, so a release build should pass the origin explicitly rather than
trust the default: a wrong origin degrades to "sync silently does nothing".
Signed-out readers keep using device-local storage exactly as before.

## Roadmap

| Step | State |
| --- | --- |
| Scraper API source + `ApiClient` auth seams | done (43 tests) |
| Clerk contract, wiring, sign-in page, account card | done |
| `clerk_flutter` dependency + adapter + APK build | done |
| Sync contract + Neon tables + migration | done |
| Mobile sync routes (PWA) + scraper Clerk JWT verification | in review |
| Sync client, offline queue, merge-on-first-sign-in | in review |
| User-scoped sync end-to-end on device | after deploy + keys |
| Web ↔ mobile saved-story reconciliation, mobile push | roadmap phases 5–6 |

### Dependency trade-off introduced by the beta SDK

`clerk_flutter` → `flutter_svg` → `vector_graphics_compiler` caps `xml` at
`7.0.1`, so the app's RSS/Atom parser dependency moved from `xml ^7.1.0` to
`xml ^6.6.1`. The parser only uses the stable document/element API, and
`test/data/rss_parser_test.dart` (part of the 264-test suite) guards that
behaviour; the pin and its reason are commented in `pubspec.yaml`.

The SDK also adds ~7.6 MB to the release APK (56.8 MB → 64.4 MB) because of
`webview_flutter`, `passkeys`, `image_picker` and `flutter_svg`. If that cost or
the beta status becomes unacceptable, delete
`lib/core/data/auth/clerk_auth_repository.dart`, drop the dependency and the two
overrides in `AppBootstrap`, and re-point `AuthRepository` at a Frontend-API
client — no feature, page or test outside the adapter knows Clerk exists.
