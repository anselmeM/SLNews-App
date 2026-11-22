# SLNews — Feature gaps

What the Samsung News reference recording shows that SLNews does not yet do, plus
the capabilities a news app is expected to have regardless of that reference.

- **Reference**: `Screen_Recording_20261016_235625_Samsung News.mp4` (68 s), sampled
  frame by frame; timestamps below are approximate (±1 s).
- **Code base at first write**: `SLNews-App` at `da9ccc2` (454 tests, 8 golden renders).
- **Status refresh (2026-11-15)**: re-audited against `master` (code 61). Current
  gates are 640 functional tests (including the push suite) plus 9 golden renders,
  analyzer clean, 76.12 % line coverage, and `scripts/check_app_coverage.py`
  enforcing per-file floors on the critical modules plus an 800-line file budget.
  Sections marked **shipped** below were re-verified in the source, not inferred
  from commit messages.
- **Legend**: P0 = blocks a normal user journey, P1 = expected, P2 = notable polish,
  P3 = nice to have. Size: S ≈ ≤½ day, M ≈ 1–3 days, L ≈ >3 days.
- Claims marked *(seen)* were observed in the video; *(inferred)* is a conclusion, not
  a frame.

---

## Part A — Gaps against the video

### A1. "Top stories" pushed page with a hero-photo header — **shipped**, M
*(seen: 11 s, 19 s, 21 s, 42 s)*

Shipped as `/top_stories` + `TopStoriesSectionPage`: a collapsing SliverAppBar with the
lead photo, scrim and section title, back chevron, story tiles, a `More top stories ›`
link and a floating back-to-top once scrolled. The For You title now pushes it (it used
to jump to the News tab), so the header behaves like a "see all". A new `section.png`
app-level golden renders it.

Still open: generic `/section/:id` pages for the other categories, and an inline ad in
this list (the reference shows one).

### A2. End-of-group "More … stories ›" links — **shipped for feed groups**, S
*(seen: 19 s "More top stories", 45 s "More NHL stories" / "More sports stories",
58 s "More Ottawa stories")*

Groups end with a right-aligned link into the full list. Current: only the top-of-group
`SectionHeader` chevron exists. Needs one shared widget and placement at group ends
(For You local rail, Sports leagues, section pages).

### A3. Following mosaic on the feed — **shipped**, M
*(seen: 55 s)*

The reference shows a `Following ›` header followed by a two-column mosaic of
**image topic cards** (Cars and Vehicles, Music, Culture, Lifestyle …), tapping through
to the Following surface.

Shipped on For You: a `TopicMosaic` two-column grid after the Latest group, four cards
from the curated category set (an image from that category's first story, a dark
fallback card with a category glyph, and a white label with a chevron). Tapping a card
pushes the photo-header section page at `/section/:categoryId`, whose "More …" link
continues to the News tab. Discovery lives on the feed; management lives on Following.

**Following screen (2026-11-15).** Rebuilt against the video: the two "Manage …" rows
became the reference's four chevron headers — Sports, Locations, Topics, Sources — each
opening its catalogue, with the followed entities rendered chip-less underneath and the
two suggestion groups ("Most popular with users", "Based on what you follow") keeping
their Follow chips. Headers render even when a group is empty, because they are the only
route into the catalogues. `Manage news sources` now lists the whole publisher catalogue
(it read followed+suggested before, and publishers are never "popular", so it was empty);
`Manage news topics` lists all eleven news sections; and the Sports header opens a new
`/following/sports` picker with every featured league plus the seeded teams instead of
jumping to the Sports tab. Inside that picker, **European Leagues** stays a single
followable section — the same merged block the Sports feed renders — and tapping the row
expands it to La Liga, Serie A, Bundesliga and Ligue 1, each opening its own league page.

**Locations removed (2026-11-15).** The app is locked to **Sierra Leone as a whole**:
city personalisation is gone from every surface, not just Following.

- Following has no Locations header, followed-city rows or location suggestions.
- **Onboarding no longer asks for a home city** — it offers topics only, and the
  "Your home city" step and its write are deleted.
- Settings loses "Manage locations" and "Followed location".
- For You loses the city rail ("From <city>"); the feed is the national mix. The rail
  machinery is untouched so a localised stream can return without a rewrite.
- The weather chip is now read-only (it used to open the city picker); it still shows
  the capital's forecast, and "Show weather forecast" in Settings hides it entirely.

The `/following/locations` screen, `locationFeedProvider`, `SlLocations` and the picker
sheet all remain in the codebase, tested, so restoring city personalisation is a header
row plus a re-wire — not a rewrite. `activeLocationId` still defaults to
`city:freetown`; it now only feeds the weather chip.

**League → team drill-in (2026-11-15).** Each league row in the sports picker gained a
chevron that drills into `/following/sports/:leagueId` — the reference's league → team
list — where a competition's seeded clubs can be followed; competitions with no seeded
sides show an empty state that links to the league page, and the merged European row
lists its four member leagues instead.

### A4. Notification permission prompt — **partially shipped** (deferred OS prompt, no priming card), M
*(seen: 3.8 s)*

An in-feed card: *"Stay on top of the news — Catch up on the top stories of the day with
Editor's picks. You can always turn them off later in Settings."* with **No thanks** and
**Turn on**.

Current: there is **no Samsung-style priming card in the feed**. Instead the OS prompt is
requested on the reader's first save or follow (`PushService.requestIfNeeded()` is called
from the save/follow controller), so it arrives at a moment the reader understands. A
previous denial is left alone and the Settings toggle is the explicit way back in. The
push stack itself exists, so the card could honestly be added; it stays open only if the
reference-matching copy is wanted.

### A5. "Add widget to Home screen" prompt — P2, L
*(seen: 55 s)*

Same card pattern for a home-screen widget. Current: no Android widget module, so only
the prompt is missing *and* would be fake without the widget.

### A6. Shopping, brand and "spotlight" ad formats — P2, M
*(seen: 22.8 s "Ultimate Shopping Spree / View more", 51 s "Idle Guy", 60.8 s
"Spotlight on Celebrity", 64.6 s "More for you")*

The reference runs several ad shapes: two-product promo with a CTA pill, app-install
promo, and a full-bleed brand "spotlight" with a colour field and a story beneath.

Current: one generic `AdCard` (image, label, CTA). Needs two or three more ad layouts in
the same rotation model.

### A7. Sports depth — **shipped (first pass)**, L
*(seen: 34 s, 39.9 s, 43.7 s, 45.6 s)*

The reference has the colour-washed scoreboard, followed teams, league-grouped story
lists with per-league "More … stories" links, inline ads and (implied by the grouping)
**league and team surfaces**.

Shipped: league pages (`/sports/league/:id`) with a standings table, that competition's
fixtures and its stories; team pages (`/sports/team/:id`) with a follow chip, fixtures
and results, and best-effort team stories; a compact standings table on the Sports tab
for the first followed league; and real navigation from followed-team/league chips, the
scoreboard strip and fixtures. `SportsLinks` maps fixture labels ("Sierra Leone Premier
League") to standings ids (`spl`) so the two vocabularies cannot drift.

Remaining for a later pass: grouped per-league story rails with "More" links, game detail
pages, and richer team stats.

**Merged soccer section (2026-11-15).** La Liga, Serie A, Bundesliga and Ligue 1 remain
one "European Leagues" block on the Sports tab, but opening it used to land on a league
page whose only content was *"No standings published for European Leagues yet."* — a
table the merged pseudo-league cannot have. That page now leads with a **Leagues** card
listing the four competitions, each opening its own league page (standings, fixtures,
stories); its fixtures block aggregates the member leagues, and the combined story feed
is unchanged. While fixing it, the page's forced dark theme turned out to be applied
only to widgets built inside it: the scaffold and row helpers read the *outer* context,
so in light mode the section headers rendered white on a light canvas. The body is now
built inside the theme (a `Builder`), which keeps the page dark end to end.

**Follows now shape the home feed (2026-11-16).** Before this, a follow only
*reordered* stories already in the pool: both feed sources were follow-agnostic, so
following Politics did nothing unless a politics story happened to be in the pool, and a
followed team had no effect at all (`personalMatch` ignored `team:`/`league:`). Now each
followed **topic** contributes its own category feed to the For You pool (capped at six
stories per topic, then ranked by the existing Sierra Leone-first mix plus the 36 h
follow boost), so following a section actually changes what appears. Teams and leagues
still do not feed For You — they drive the Sports tab and push segments — and the
personalisation remains *invisible*: there is no "Because you follow X" rail yet.

**Sports follow state (2026-11-16).** `SportsViewModel` merged the whole sports
*catalogue* into its "followed" list, so every seeded team and league rendered as
followed, the hero team was always the first catalogue team, and a fresh install showed
"Los Angeles Lakers news" with Lakers fixtures. Only ids in `followed` now qualify (the
catalogue only repairs labels/crests), and the hero prefers a followed team ESPN covers
so the "team news" and fixture sections are real. A scoreboard fixture labelled with a
member competition ("La Liga") is also folded onto the "European Leagues" block instead
of spawning a second section.

### A8. Stocks opened as a panel over the feed — **shipped**, S
*(seen: 47 s)*

Both For You entry points (header chevron and card) now slide the board up as a modal
panel over the feed, matching the reference; the `/stocks` route remains for deep links
and tests.

### A9. Reader: publisher page vs native text — **shipped as a second mode**, M
*(seen: 1.9 s)*

Samsung renders the **publisher's own page** (note the site's blue bar, hamburger and
search) inside its reader, with a 4-item floating bar: Follow (publisher avatar), like,
`aA`, menu.

Shipped: the native reader stays the default, and its toolbar gains **Read original**
(`/article/:id/original`). That route loads the publisher page in an embedded
`flutter_inappwebview` with an overlay back/publisher/Reader header, the reading-progress
hairline, the same floating action bar, and `aA` re-injecting the root font size through
JavaScript. Same-publisher links stay in the page, external links leave through the
platform, and offline / missing-link / blocked pages fall back to the native reader.
Cookies and cache are ephemeral (`incognito: true`).

### A10. Video-moment card badges — **shipped**, S
*(seen: 26–32 s)*

Cards carry the **outlet's logo badge** over the thumbnail and a play glyph; the reference
also implies a duration.

Current: `VideoMomentCard` shows a source line and title; no logo badge, play glyph or
duration.

### A11. Video scrubber / time — P2, M
*(seen: 28 s; a longer clip shows a progress bar and elapsed time)*

The reel is play/pause + mute + full screen + like only; there is no scrubber or elapsed
time (the embedded player's own controls are not exposed).

### A12. In-feed "More for you" rail — P3, S
*(seen: 64.6 s)* The reference has an extra personalised rail beyond Picks / Next read.

---

## Part B — What a news app needs that SLNews is missing

### B1. Search — P0 → **v1 shipped**, L
Search v1 now exists: entry from the page kebab (`PageMenuAction.search`), `/search`
route, autofocused field, 250 ms debounce, results grouped into **Stories** and
**Videos**, persisted **recent searches** with clear, and honest empty/no-result/error
states. `search_page_test` covers each path.

Still open for a v2: suggestions from followed topics, search-as-you-type ranking and
relevance (the repository does a substring match), voice input, and author/topic results.

### B2. Push notifications (mobile side) — **shipped (v1)**, M+L
The backend had FCM sending (`SLNews/src/lib/push/fcm.ts`) and the device endpoint
(`/api/mobile/v1/devices`); the app now integrates both:

- Firebase initialised with graceful degradation when the platform config is absent.
- Permission priming deferred to the first save/follow, with a silent re-register at
  startup for devices that already granted it.
- Token registration and refresh (`onRegistered`) through the session token — the
  release build carries no static key.
- Foreground display via `flutter_local_notifications` on the `breaking_news` channel.
- Tap → article routing (`PushService.taps` → router).
- FCM topic segments derived from follows plus the notification toggles, diff-based,
  persisted under `push.topics` and reconciled on restart so removed topics are
  unsubscribed rather than forgotten.
- `PushStatus` is a sealed hierarchy (`PushUnavailable`, `PushPermissionDenied`,
  `PushDisabled`, `PushRegistered`, `PushFailed`).

Remaining: separate notification channels per segment (only `breaking_news` exists),
quiet hours, in-app badge counts, the iOS APNs capability, and the reference priming
card (A4).

### B3. Reading experience — P1
- **Reading progress** indicator shipped. Persisted scroll position per article is still
  open.
- **In-app translation** (currently a hand-off to Google Translate in the browser).
- **Listen / TTS** for articles.
- Font family choice, brightness control inside the reader, image lightbox and captions.
- Long-press/selection beyond default; internal handling of links inside article bodies.

### B4. Offline and data — **first pass shipped**, M
*(partly done)*

Shipped: article bodies already travelled with the cached `Article` JSON, so cached
stories read offline. Now a **story that was never cached** (a deep link outside the
rails) is resolved on demand through the single-article endpoint and written to the cache,
so the next offline open of that link has a body. The Saved stories screen states plainly
that saved stories are kept on the device and stay readable offline.

Remaining: data-saver image quality, Wi-Fi-only video autoplay, a cache/storage screen
with "clear images", and background refresh (WorkManager) so the feed is warm ahead of
the first open.
### B5. Platform integration — P1, M
- **Android home-screen widget** (A5) and app shortcuts ("Search", "Saved").
- **Verified App Links / Universal Links**: the manifest declares
  `slnews://article/<id>` (custom scheme, works today). No HTTPS App Link intent
  filter is declared and no `assetlinks.json`/AASA is checked in, so shared https
  links still do not open the app — this remains the gap.
- Share target (receive links into the app), iOS notification/push capability, tablet
  and landscape layouts. (Android 13's `POST_NOTIFICATIONS` is already declared.)

### B6. Account and personalisation — P1, S+M
- Sign-in (Clerk) and account-scoped sync exist, and the **account screen** shipped
  (`/account`: identity, sign in/out, **delete account** with confirmation and
  failure handling). Missing: **export data**, password/email management, device list.
- **Language picker shipped for English/French** (device default, persisted); Krio is disabled pending a translator. Only shell/Settings strings are extracted so far, so most screens remain English-only.
- No recommendation feedback ("not interested", "more like this"), and rails are positional
  slices of one stream rather than a ranking.
- Author/publisher pages and following authors from the article kebab.

### B7. Trust, legal, compliance — P1, S+M
- In-app **privacy policy** and **terms of use** shipped (Settings → About opens the
  live URLs), and account deletion is implemented end to end. Missing: an editorial
  standards / corrections page.
- Consent flow for analytics/ads (GDPR-style), ad labelling beyond the current "Ad" tag,
  frequency capping.
- **Content licensing**: the feed mixes scraped RSS with original reporting — attribution
  and rights review are a product/legal gap, not just code.
- Report flow exists; authoring side and response process do not.

### B8. Accessibility and localisation — **first pass shipped**, M

Shipped: semantic labels on the new surfaces (topic mosaic cards announce "Open …",
standings rows announce rank/team/record, score cards announce the fixture as a button),
decorative images are excluded from the semantics tree while content images can be
labelled, and a 200 %-text-scale regression test covers the settings screen. Reduce-motion
was already implemented via `AppMotion`.

Shipped: `flutter_localizations` + `intl` + ARB catalogs (en/fr) and a Settings language picker. Remaining: most screen strings are not yet extracted, and no RTL; Krio, Mende, Temne
and French are the languages a Sierra Leonean product would consider. A full
TalkBack/VoiceOver pass over every screen, plus contrast verification, is still to do.

### B9. Monetisation — P2, L
No real ad SDK (in-house cards only), no sponsored-content model, no membership/support
tier, no consent management.

### B10. Reliability and observability — P1, M
- Crash reporting shipped (Sentry behind `SentrySettings`/`AppLog`, DSN at build time,
  no PII, sampled traces). Still missing: product analytics, remote config/feature
  flags, and an explicit offline/connectivity state.
- No force-update gate and no staged rollout path.
- Testing is widget/unit + goldens (640 functional + 9 golden renders) with a
  76 % total-line-coverage gate, per-file floors on the critical modules and an
  800-line file budget. There is still **no on-device integration or CI
  end-to-end test**, which is how push, deep links and offline would normally be
  verified.

### B11. Editorial operations (backend, surfaced in app) — P2, L
Curated top stories, push composer, sponsored slot management, and analytics dashboards
are needed to *operate* the app; the app side only needs to consume those overrides.

---

## Part C — Suggested order

**Quick wins — done in this pass**
1. ~~Saved-stories entry point~~ (`4572183`).
2. ~~Global offline banner + "updated x ago" on all tabs~~ (`4572183`).
3. ~~Article body caching~~ — verified already working; regression tests added (`566d8bd`).
4. ~~Reading progress bar~~ (`1398437`).
5. ~~"More … stories ›" links (A2)~~ (`abc101f`); the extra "More for you" rail (A12) remains.
6. ~~Video card badges (A10)~~ (`2e51e6e`) and ~~Stocks as a panel (A8)~~ (batch 3).

**Then (one to two weeks) — all three delivered**
7. ~~Search v1 (B1)~~: route, entry point, debounced query, results, recents.
8. ~~Push v1 (B2)~~: FCM transport, permission flow, token registration, per-topic
   segments, deep link. The reference priming card (A4) remains open.
9. ~~Top stories section page with hero header (A1)~~.

**Later (multi-week, need decisions or content ops)**
10. Sports depth (A7): standings, league/team/game pages, league grouping.
11. Following mosaic (A3), ad formats (A6), widget + shortcuts (A5, B5).
12. Account deletion/export, privacy/terms, analytics + crash reporting, localisation.
    *(account deletion and privacy/terms have since shipped — see Part D)*

---

## Part D — Deferred post-launch backlog (explicitly **not** launch blockers)

Verified against `master` (`cc1328b`) on 2026-11-15. None of these blocks the code-61
release. Each row states what already exists, what the real dependency is, an effort
band, and how "done" would be recognised. Effort bands are engineering-day estimates,
not commitments.

| Item | Where it stands | Real dependency | Effort | Acceptance |
| --- | --- | --- | --- | --- |
| **Web ↔ mobile saved-story parity** | **Mobile half done.** `MobileBookmark` already serialises `sourceUrl` and [SYNC-API.md](SYNC-API.md) documents it, so the join key already reaches the backend. The PWA has no stable key to join on (`SavedArticle.articleId` points at a PWA row). | PWA-repo change: additive `Article.sourceUrl @unique` + backfill from the scraper sync; needs owner approval for a production schema change (ROADMAP phase 5). | PWA ~2–3 d + backfill run; nothing to build in this repo | A story saved on mobile appears on the web profile and vice versa, de-duplicated by canonical URL |
| **Localisation + RTL** | **Foundation shipped**: `flutter_localizations`, `intl`, en/fr ARBs, generated delegates at the app root, and a Settings language picker (Krio disabled pending translation). Only shell/Settings strings are extracted; most screens still hardcode English. No RTL work. | Product decision on the language set (Krio, Mende, Temne, French?) and who translates editorial/UI copy. | ~5–8 d scaffolding + English ARB + one second locale; ~1 d per further locale | `flutter gen-l10n` in place, no user-visible literal left in `lib/`, a second locale renders end to end, RTL screenshot test |
| **Richer ad formats (A6)** | One `AdUnit` shape: brand panel, optional hosted creative image, CTA, disclosure; `AdCard`/`TrackedAdCard` render it in every placement. Tracking is per sold unit with session dedupe. | Creative/design input, plus a `format` discriminator on `/api/mobile/v1/sponsorships` so a campaign picks a layout. | ~3–4 d | Two-product promo, app-install promo and full-bleed "spotlight" layouts selectable per campaign, each measured by the existing tracker |
| **Android home-screen widget (A5)** | **Shipped basic widget**: Android receiver, headline + breaking-count layout, tap-through, feed-driven refresh. Missing: scheduled refresh, iOS widget, widget-prompt card. | Data access off the Flutter engine: the cache is Hive, which a widget cannot open cheaply — needs a small JSON/snapshot file (or WorkManager) as the widget's feed. | ~5–7 d | Widget shows top headlines, refreshes on a schedule, tapping a headline deep-links via `slnews://article/<id>` |
| **Article TTS + in-app translation (B3)** | **TTS shipped**: reader Listen/Stop with an injectable engine, stops on exit. Translation is still a hand-off to Google Translate. | TTS is self-contained. Translation needs a provider, a cost cap, and a content-licensing answer (machine-translating aggregated publisher text). | TTS ~1–2 d; translation ~3–4 d + provider cost | Listen controls (play/pause/seek) on the reader; translate renders copy in-app with a clear "machine translation" label |
| **On-device / E2E tests (B10)** | Absent: no `integration_test` dependency or `integration_test/` directory. CI runs format → analyze → secret scan → widget/unit tests → coverage ratchet only. | An emulator runner in CI and Firebase/Gradle credentials; the golden suite is deliberately host-local, so it cannot substitute. | ~4–6 d | A CI job drives a real build on an emulator through onboarding → feed → article → airplane mode, plus a push/deep-link path |

**Suggested order if any of these is picked up:** parity first (cheap in this repo,
unblocks the web), then E2E (protects everything else), then TTS (quick win), then ad
formats, then widget, then localisation (largest and needs product decisions).

---

## Appendix 1 — Recently closed from this list

| Item | Commit |
| --- | --- |
| Trending now numbered rail | `da9ccc2` |
| Sports scoreboard card (colour-washed, credited) | `da9ccc2` |
| Stocks index board + `/stocks` page with filter tabs and sparklines | `da9ccc2` |
| Video reel (full-bleed, rail, badge, caption, segments, tap-pause) | `0e17a77` |
| Reader meta block (section label, `Published:` line) | `308088a` |
| Micro-animation layer (press, entrance, springs, page fades) | `3f20b81` |
| For You sections rail (Video moments, Picks, Next read, ads) | earlier |
| Saved-stories entry point in the page menu (the route was unreachable) | `4572183` |
| Offline banner on all four tabs via `SlPageScaffold` | `4572183` |
| Offline article bodies verified end to end (cache carries the body) | verified |
| Reading progress bar in the reader | `1398437` |
| "More … stories ›" group links (For You local rail, Sports card) | `abc101f` |
| Video cards: outlet monogram badge + clip length when supplied | `2e51e6e` |
| Search v1 (kebab entry, `/search`, debounce, grouped results, recents) | `53d6ce1` |
| Pushed Top stories section with photo header + `section.png` golden | `3f9f35c` |
| Stocks as a slid-up panel from For You | batch 3 |
| Account screen with sign-out and delete-account | code 61 |
| In-app privacy policy / terms rows in Settings | code 61 |
| Push v1: FCM transport, segments, tap routing | code 52+ |
| Crash reporting (Sentry behind `AppLog`) | code 52+ |
| Web ↔ mobile state sync (Clerk, merge-on-sign-in) | roadmap T4 |
| Following rebuilt to the reference: chevron headers, publisher/topic/sports pickers | 2026-11-15 |
| `JsonArticleMapper` unit tests (was 0 % covered) | 2026-11-15 |

## Appendix 1b — Sections re-verified in the 2026-11-15 refresh

These were re-read in source rather than trusted from the earlier document: A4 (no
priming card; deferred OS prompt via `PushService.requestIfNeeded`), B2 (push v1),
B3 (reading progress), B5 (`slnews://` only, no HTTPS App Link filter), B6 (account
page), B7 (legal rows), B10 (Sentry). Counts in this document now match the code at
`cc1328b`: 640 functional tests (including the push suite), 9 golden renders.

## Appendix 2 — Already matching the reference

Verified against frames, so these are **not** gaps: three-dot kebab menu and settings;
bottom navigation with four tabs and a notification icon; hero carousel with page dots;
tile cards with publisher mark, age and like; inline ads labelled "Ad"; weather/temperature
chip and BREAKING tag; pull-to-refresh; skeletons; back-to-top button; video moments rail
with "See what's new"; full-screen reel; article keyword tags; related stories; saved
stories list; dark mode; text-size control; notification history with mark-all-read.

## Appendix 3 — Method

Frames sampled every 1.9 s (36 frames, contact sheets of 9) plus targeted full-resolution
grabs around transitions; each Part A row cites the frame time. Code state came from a
read-only audit of `lib/` (routes, pages, widgets, providers) plus `pubspec.yaml` and
`AndroidManifest.xml` on `da9ccc2`. Nothing in this document was written from memory of
the reference alone: a row is either seen in a frame or marked *(inferred)*.
