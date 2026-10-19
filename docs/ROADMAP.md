# SLNews platform roadmap — backend first

Owner: platform (mobile + backend). Last updated: 2026-10-16.

Scope: turn the Flutter app's device-local reader state into **account-scoped,
cross-device state**, and remove the last shared-secret from the mobile client.

Repos touched:

| Repo | Role in this roadmap |
| --- | --- |
| `SLNews` (Next.js + Prisma + Neon + Clerk) | owns identity and user data; hosts the new mobile sync API |
| `SLNewsAPIScapper` (Express + Prisma + Neon) | content API; gains Clerk JWT verification |
| `SLNews-App` (Flutter) | sync client, merge-on-first-sign-in, Clerk session |

Both backend repos are branch-protected: every change lands through a feature
branch, conventional commits and a PR. Local gates before pushing are
`npm run test:run && npm run typecheck && npm run lint` (PWA) and
`npm test && npx tsc --noEmit && npm run lint` (scraper).

## Where we are

| Done | Evidence |
| --- | --- |
| Scraper API consumed as a real content source (`/v1/news`, 43 tests) | `lib/core/data/sources/sl_news_api_source.dart` |
| Clerk identity in the app behind `AuthRepository` (beta SDK isolated) | `lib/core/data/auth/clerk_auth_repository.dart` |
| Offline-first content pipeline + 264 app tests | `flutter analyze`, `flutter test` |

| Missing | Consequence today |
| --- | --- |
| Mobile user state is device-only (Hive) | reinstall or second device = bookmarks, likes and follows are gone |
| Scraper authorises with a static key embedded in the app | extractable; no per-user identity or quota |
| No stable join key between PWA `Article` rows and scraped articles | web and mobile "saved stories" cannot be reconciled yet |

## Phase 1 — Sync contract (no code dependencies)

**Goal:** freeze the interface before either side implements it.

- **T1.1** `docs/SYNC-API.md` in `SLNews-App`: endpoints, payloads, idempotency,
  conflict rule (last-write-wins on `updatedAt`), delta cursor, error codes,
  versioning (`/api/mobile/v1`), and the item-id scheme (`slnews-api:123`,
  `rss:<hash>`, `web:<cuid>`).
- **T1.2** Document the merge-on-first-sign-in rule: local wins on conflict, union
  otherwise, deletions are tombstoned so they cannot resurrect.

## Phase 2 — Backend: mobile sync API (PWA)

**Goal:** account-scoped bookmarks, likes and follows for the mobile client.

Design decision: **snapshot rows, not joins.** The PWA `SavedArticle` points at a
PWA `Article` row, which mobile items have no stable mapping to (the PWA content
model has no external id — see Phase 5). Mobile sync therefore stores its own
user-scoped rows carrying just enough display data to render a saved list
offline, keyed by the mobile item id. Nothing in the existing web tables changes.

- **T2.1** Additive Prisma models: `MobileBookmark`, `MobileReaction`,
  `MobileFollow` (`userId` = Clerk id, `itemId`, snapshot fields,
  `updatedAt`, `deletedAt` tombstone; unique on `(userId, itemId)` /
  `(userId, itemId, kind)`; indexes on `(userId, updatedAt)`).
- **T2.2** `GET /api/mobile/v1/sync?since=<iso>` — delta pull of all three
  collections plus `serverTime` and `hasMore`.
- **T2.3** `POST /api/mobile/v1/sync` — batched idempotent upserts and tombstones,
  LWW by `updatedAt`; returns the applied state so the client can converge in one
  round trip.
- **T2.4** Guard rails: Clerk `auth()`, per-user rate limit via the existing
  `checkDbRateLimit`, payload validation and size caps, `reportError` on failure.
- **T2.5** Vitest coverage for both routes: unauthenticated → 401, delta filter,
  tombstone handling, LWW conflict, payload validation, rate limiting.
- **T2.6** Migration prepared (`prisma migrate diff` SQL) and applied only with
  owner approval; deploy notes for Vercel env.

## Phase 3 — Backend: scraper accepts Clerk JWTs

**Goal:** retire the static key from the mobile client without breaking the PWA.

- **T3.1** `requireAuthentication` replaces `requireApiKey`: accept the existing
  static bearer key **or** a Clerk session JWT whose signature verifies against
  Clerk's JWKS and whose claims pass (`exp`, `nbf`, `azp` in the authorised set).
- **T3.2** Config `CLERK_SECRET_KEY` / `CLERK_AUTHORIZED_PARTIES`; absent →
  behaviour is exactly today's (static key only), so the PWA is unaffected.
- **T3.3** Vitest: valid JWT, wrong signature, expired, wrong `azp`, missing
  header, static key still works, JWKS fetched once and cached, key rotation.
- **T3.4** Document Render env changes and the rollout order (scraper first,
  mobile second).

## Phase 4 — Mobile: sync client + merge on first sign-in

**Goal:** the app writes locally as it does today, and converges when signed in.

- **T4.1** `SyncApiClient` (Dio) + `SyncRepository` contract in
  `core/domain/sync`, offline-first: local write always succeeds, sync is queued
  and retried.
- **T4.2** Merge-on-first-sign-in: push local state, pull server state, union
  with last-write-wins, tombstone local deletions.
- **T4.3** Wire `bookmarksControllerProvider`, `likesControllerProvider` and
  `followingControllerProvider` to enqueue sync; surface sync state in the
  account card (signed in — last synced / retry).
- **T4.4** Tests: stubbed adapters for push/pull/merge, tombstone round-trip,
  offline queue replay, conflict resolution; plus a widget test for the account
  card's sync state.
- **T4.5** Point the app's Clerk token at the PWA host allow-list so the session
  JWT is attached to sync calls (never to publisher feeds — already enforced).

## Phase 5 — Web ↔ mobile content parity (flagged, needs a decision)

`SavedArticle.articleId` references a PWA `Article` row and the mobile ids are
external, so cross-surface saved stories cannot be reconciled until the PWA
content model gains a stable source key.

- **T5.1** Additive `Article.sourceUrl @unique` (or `externalId`) + backfill from
  the scraper sync, then reconcile `SavedArticle` with `MobileBookmark`.
- **T5.2** Show mobile-saved stories on the web profile and vice versa.
- Out of scope until the owner approves a production schema change + backfill.

## Phase 6 — Mobile push notifications (later)

Reuse `PushSubscription` + `web-push` with FCM/APNs transport; the mobile model,
storage and history UI already exist. Needs Firebase/APNs credentials.

## Status — 2026-10-16

| Task | State | Evidence |
| --- | --- | --- |
| T1.1–1.2 sync contract + merge rule | done | [SYNC-API.md](SYNC-API.md) |
| T2.1 additive Prisma models | done | `SLNews/docs/mobile-sync-migration.sql` (idempotent, applied by the deployment) |
| T2.2–2.4 sync routes (pull/push/auth/limits) | done | `SLNews` PR [#101](https://github.com/anselmeM/SLNews-Web/pull/101) |
| T2.5 route + engine tests | done | 73 new PWA tests; full suite 609 green |
| T2.6 schema present in the deployed database | done | applied by `vercel-build` (`SLNews` PR [#102](https://github.com/anselmeM/SLNews-Web/pull/102)); proven by the production end-to-end run |
| T3.1–3.3 scraper accepts Clerk JWTs | done | `SLNewsAPIScapper` PR [#8](https://github.com/anselmeM/SLNews-WebAPIScapper/pull/8) — 125 tests, static-key path proven unchanged |
| T4.1–4.2 sync client, ledger, merge-on-sign-in | done | `lib/core/{domain,data}/sync`, `LocalSyncLedger`, `SyncController` |
| T4.3–4.5 wiring, account card, token allow-list | done | controllers hook changes; `AccountCard` shows sync state |
| T4.4 mobile sync tests | done | 90 new tests; `flutter analyze` clean, 354 total |
| T4.6 precise 429 backoff | done | `ApiException.responseHeaders` carries `Retry-After`, so the thrown path yields `SyncRateLimited.retryAfter` instead of a null hint (4 tests) |
| T5 web ↔ mobile content parity | not started | needs `Article.sourceUrl` (owner decision) |
| T6 mobile push notifications | not started | needs FCM/APNs credentials |

**End-to-end proof** (not just unit tests): `SLNews/scripts/verify-mobile-sync.mjs`
mints a real Clerk session token for a throwaway probe user and drives the real
contract, then deletes the probe. It passes **17/17 checks** — invalid token →
401, first sync creates the Postgres user, push applies, re-push is idempotent,
newer `updatedAt` wins, older is rejected `stale`, a tombstone applies and cannot
be resurrected by a stale push, delta pull returns the tombstone, and the 400/413
caps hold.

**That run is now against production**
(`--base https://sl-news.vercel.app`). It first passed against a *locally running*
PWA while the deployed API answered **500** for every authenticated request: the
tables had been created by hand against the local Postgres and never existed in
the database the deployment talks to (`The table public.MobileBookmark does not
exist`, from the Vercel logs). A green localhost run is not deployment
verification — the schema now travels with the deploy, and the 17/17 result was
re-produced against the deployed origin.

**Bug that only a live run could catch:** the PWA resolver read `.data`/`.errors`
off `verifyToken` (the removed `@clerk/backend` v1 shape). v3 resolves with the
claims and throws on failure, so every valid session token was 401'd. The unit
tests mocked the same wrong shape; the resolver, its mocks and the contract note
are now fixed.

## Verification plan

| Layer | Command | Expected |
| --- | --- | --- |
| PWA backend | `npm run test:run && npm run typecheck && npm run lint` | all green |
| Scraper backend | `npm test && npx tsc --noEmit && npm run lint` | all green |
| Mobile | `flutter analyze && flutter test test/core test/data test/features` | 0 issues, all pass |
| Live | `scripts/smoke_api.ps1` + signed-in sync round trip | after deploy + keys |

## Risks

| Risk | Mitigation |
| --- | --- |
| Tables missing in the database a deployment uses | `vercel-build` applies the idempotent SQL and **fails the deploy** if the objects are absent, so a half-migrated database cannot serve 500s silently |
| Beta Clerk SDK churn | already quarantined behind `AuthRepository` |
| Node locally 24 vs PWA `.nvmrc` 22 | run the repos' gates; CI remains the authority |
| Hand-rolled JWT verification | use the official Clerk backend SDK rather than bespoke crypto |
