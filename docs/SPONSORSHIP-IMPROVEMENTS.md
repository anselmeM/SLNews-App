# Sponsorship improvements — task list

**Scope:** Flutter app (`SLNews-App`), mobile sponsorship API and admin (`SLNews-Web`), Prisma schema.
**Goal:** Make sponsored inventory safe to sell: correct click-through, defensible measurement, reliable admin operations and clear reporting.
**Status legend:** `[ ]` pending · `[~]` in progress · `[x]` done

## Priority order

| # | Task | Repo | Status |
|---|---|---|---|
| 1 | Shared CTA/open helper; count taps only for valid targets | App | [x] |
| 2 | Align placements and implement `article_end` inventory | App + Web | [x] |
| 3 | Revalidate sponsorship reads after admin changes | Web | [x] |
| 4 | API validation parity with the admin form | Web | [x] |
| 5 | Signed event tokens, dedupe, active/window checks | App + Web | [x] |
| 6 | Daily metrics, date-range report and CSV export | Web | [x] |
| 7 | Campaign edit, duplicate and archive lifecycle | Web | [x] |
| 8 | Admin UX: effective status, schedules, confirmations, preview/errors | Web | [x] |
| 9 | Priority, rotation, pacing and slot capacities | App + Web | [x] |
| 10 | Image hardening: magic bytes, dimensions, alt text, external URL policy | Web + App | [x] |
| 11 | Admin auth, audit trail and centralized route guard | Web | [x] |
| 12 | App tracking outbox and viewability semantics | App | [x] |
| 13 | Remove or unify the dead web sponsor registry | Web | [x] |
| 14 | Tests for CTA, measurement, reports and admin UI | Both | [x] |
| 15 | Reporting, disclosure and accessibility polish | Both | [x] |
| 16 | Separate News slot, every-impression events, anonymous reach/frequency and ad policy | App + Web | [x] |

## Acceptance criteria

### 1. CTA/open helper
- One shared helper opens only absolute `http`/`https` sponsor targets.
- News, Sports, For You and article surfaces use it.
- A tap is counted only when a target exists and the platform accepts the launch.
- Missing/invalid targets show a useful message and do not count a tap.
- Widget/unit tests cover valid, missing and rejected targets.

### 2. Placements
- A single placement allow-list is enforced by app, API and admin; the DB column stays text so the no-migrations `db push` workflow cannot require a destructive enum cast.
- `feed` is For You only; `news_stream` is a separate sellable News placement.
- `sports_stream` and `article_end` remain singleton placements.
- The server returns at most 2 units for feed and 1 for each singleton placement; the app renders the returned order without client-side selection.
- Admin options exactly match renderable placements.
- Tests cover each placement and reject unknown ones.

### 3. Cache invalidation
- Creating, stopping, extending, reactivating, editing or duplicating a campaign revalidates the public sponsorship read.
- Admin notice/read path reflects changes immediately.
- Test covers the revalidation call.

### 4. API validation
- Server enforces placement enum, field lengths, `#RRGGBB` colours, http(s) URLs, no URL credentials, valid start/end ordering, optional end date.
- Same rules as `parseCampaignForm`.
- Tests cover every rejection and a valid create.

### 5. Event integrity
- Ad responses include a short-lived signed event token bound to the campaign; the app supplies a stable event id, and the server dedupes replays.
- Event endpoint rejects missing/invalid/expired tokens, inactive/out-of-window campaigns and unknown IDs.
- Replays and duplicate events are ignored via an event/meter key.
- App sends the token; failed sends retry without double counting.
- Tests cover forged, expired, replayed and inactive cases.

### 6. Reporting
- Daily impressions/taps are stored per campaign and UTC day.
- Report API supports `from`/`to`, returns daily series, totals with CTR, unique reach and average frequency.
- Reach is distinct hashed install ids per campaign in the range; null when no identifiable reach exists.
- Admin report page supports date range, CSV export, per-campaign rows and category.
- Tests cover date filtering, reach/frequency and CSV shape.

### 7. Admin lifecycle
- Edit an existing campaign without recreating it.
- Duplicate a campaign as a stopped draft.
- Archive (soft delete) removes it from the default list and public API.
- Tests cover edit/duplicate/archive.

### 8. Admin UX
- Derived status is shown: draft, scheduled, live, paused, expired.
- Dates validate and display in the operator timezone.
- Stop/reactivate/test-push require confirmation.
- Validation errors preserve entered values; upload preview is available.
- Empty defaults replace the prefilled demo campaign; demo seeding is explicit.
- Tests cover the form parser/status derivation.

### 9. Delivery
- Campaigns have priority/weight, start/end scheduling and optional daily/total impression caps.
- Public API returns a deterministic weighted selection: at most 2 feed units, at most 1 for each singleton placement.
- App shows exactly the server-selected units in server order.
- Tests cover ordering, caps, slot capacity and fallbacks.

### 10. Image hardening
- Upload verifies magic bytes and dimensions, rejects oversized pixel dimensions and non-images.
- Sold campaigns require alt text (or a safe default).
- External creative URLs are restricted to approved hosts or proxied.
- Tests cover fake MIME, oversized dimensions and alt handling.

### 11. Admin security
- All protected admin routes share one guard.
- Mutations write an audit entry with action, campaign, actor label and timestamp.
- Cookie/session expiry and key rotation are documented; login rate limiting retained.
- Tests cover audit writes and unauthenticated redirects.

### 12. App tracking
- One event is posted for every viewable impression and every successful tap (no once-per-campaign-per-session dedupe).
- Each event has a fresh event id; an outbox retry reuses that event's id so the server dedupes only the retry.
- The app sends a stable anonymous 32-hex install id; the server stores only a keyed hash for reach reporting.
- Events are queued persistently and flushed later on failure.
- Tests cover visibility, retry, event-id uniqueness, install-id stability and queue flush.

### 13. Web registry
- Either remove `DIRECT_SPONSOR_CAMPAIGNS` or make it DB/admin driven.
- No second source of ad truth remains.
- No dead imports or unused types.

### 14. Tests
- App: CTA helper, placements, tracker, queue, article-end ad.
- Web: API validation, event tokens, report dates/CSV, admin edit/duplicate/archive, audit.
- Both suites/lint/typecheck/analyze pass.

### 15. Polish
- CTR formatting is consistently percentage in UI/API docs.
- Sold campaigns require/label disclosure.
- Admin and report tables are accessible and mobile-readable.
- Documentation updated with impression definition, retention and invoice basis.

## Out of scope for this pass
- True Play Integrity/device attestation for event anti-fraud (documented as a later step; signed tokens + dedupe are the interim control).
- Programmatic ad networks and consent management.
- Full contract/invoice accounting beyond the fields needed by the admin report.

## Verification commands

```powershell
# App
flutter analyze --no-pub
flutter test test/core test/data test/features test/sync test/push test/security

# Web
npm run lint
npm run typecheck
npm test
```
## Implementation map

| Area | Main files |
|---|---|
| CTA and tap accounting | `lib/core/ads/sponsorship_launcher.dart`, `lib/core/widgets/tracked_ad_card.dart` |
| Placements / article-end | `lib/core/domain/models/ad_placement.dart`, `lib/features/article/presentation/article_page.dart` |
| Event contract and outbox | `lib/core/data/sources/sponsorship_tracker.dart`, `lib/core/domain/models/ad_unit.dart` |
| Admin lifecycle/reporting | `src/app/admin/sponsorships/page.tsx`, `[id]/edit/page.tsx`, `report/page.tsx`, `actions.ts` |
| Validation and tokens | `src/lib/sponsorship-validation.ts`, `src/lib/sponsorship-events.ts` |
| Rotation, caps and cache | `src/lib/sponsorship-rotation.ts`, `src/lib/sponsorship-cache.ts` |
| Daily metrics/reporting | `src/lib/admin/sponsorship-report.ts`, `prisma/schema.prisma` |
| Image hardening | `src/lib/admin/ad-upload.ts`, `src/lib/sponsorship-validation.ts` |
| Ops documentation | `docs/SPONSORSHIP-OPERATIONS.md` |

## Verification

- App: **759 tests passed**, analyzer clean, **80.30%** line coverage; app new-file gates pass.
- Web: **624 tests passed**, lint and typecheck clean.
- The production database still needs the `db-schema` workflow (`discover` then `apply`) before this branch is deployed, because the new `SponsorshipDailyMetric`, `SponsorshipEvent` and `AdminAuditLog` tables are not in production yet.

## Known residuals

- Event tokens are signed per campaign and deduped by event id, but there is no Play Integrity/device attestation yet; treat delivery numbers as rendered/invoice inputs, not audited measurement.
- The public ad response keeps a 60-second CDN cache; admin writes invalidate the data-cache tag, but a CDN edge can retain a response for its TTL.
- The admin has unit/server coverage but no browser/E2E test yet.
