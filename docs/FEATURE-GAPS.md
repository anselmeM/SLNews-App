# SLNews — Feature gaps

What the Samsung News reference recording shows that SLNews does not yet do, plus
the capabilities a news app is expected to have regardless of that reference.

- **Reference**: `Screen_Recording_20261016_235625_Samsung News.mp4` (68 s), sampled
  frame by frame; timestamps below are approximate (±1 s).
- **Code base**: `SLNews-Mobile` at `da9ccc2` (454 tests, 8 golden renders).
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

### A3. Following mosaic on the feed — P1, M
*(seen: 55 s)*

The reference shows a `Following ›` header followed by a two-column mosaic of
**image topic cards** (Cars and Vehicles, Music, Culture, Lifestyle …), tapping through
to the Following surface.

Current: the Following tab lists groups as compact rows/chips; For You has no Following
section at all. Needs an image-backed topic grid widget plus a For You rail.

### A4. Notification permission prompt — P0 once push exists, M
*(seen: 3.8 s)*

An in-feed card: *"Stay on top of the news — Catch up on the top stories of the day with
Editor's picks. You can always turn them off later in Settings."* with **No thanks** and
**Turn on**.

Current: absent, and the app has **no push stack at all** (no FCM dependency, no token
registration), which is why the button cannot honestly exist yet. See B2.

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

### A7. Sports depth — P1, L
*(seen: 34 s, 39.9 s, 43.7 s, 45.6 s)*

The reference has the colour-washed scoreboard, followed teams, league-grouped story
lists with per-league "More … stories" links, inline ads and (implied by the grouping)
**league and team surfaces**.

Current: scoreboard strip + the new spotlight card + followed-teams row + one news list +
fixtures for the first followed team. `standingsProvider` exists but has **no UI**;
tapping a team, league or game shows a snackbar — there are **no league, team or game
detail pages**.

### A8. Stocks opened as a panel over the feed — **shipped**, S
*(seen: 47 s)*

Both For You entry points (header chevron and card) now slide the board up as a modal
panel over the feed, matching the reference; the `/stocks` route remains for deep links
and tests.

### A9. Reader: publisher page vs native text — P2, S (decision, not dev)
*(seen: 1.9 s)*

Samsung renders the **publisher's own page** (note the site's blue bar, hamburger and
search) inside its reader, with a 4-item floating bar: Follow (publisher avatar), like,
`aA`, menu.

Current: native reader (section label, wordmark, headline, byline, `Published:` line,
body, tags, related stories) with 6 actions; translate opens Google Translate externally.

Trade-off: the native reader is the reason offline reading and text-size control work.
Recommendation: keep native, and close the functional gap with B3 items (in-app
translation, reading progress) rather than embedding publisher pages.

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

### B2. Push notifications (mobile side) — P0, M+L
The backend already has FCM sending (`SLNews/src/lib/push/fcm.ts`) and the device
endpoint (`/api/mobile/v1/devices`), but the **app has no push integration**: no
Firebase/APNs dependency, no token registration, no permission flow, no handler for
foreground/background messages, no deep link from a notification.

Missing pieces: permission priming + OS request (Android 13 `POST_NOTIFICATIONS`, iOS
`requestAuthorization`), token registration/refresh to the backend, notification channels
(breaking/sport/daily), tap → article route, per-topic and per-team alert settings
(toggles exist but control nothing), quiet hours, and in-app badge counts.

### B3. Reading experience — P1
- **Reading progress** indicator and persisted scroll position per article.
- **In-app translation** (currently a hand-off to Google Translate in the browser).
- **Listen / TTS** for articles.
- Font family choice, brightness control inside the reader, image lightbox and captions.
- Long-press/selection beyond default; internal handling of links inside article bodies.

### B4. Offline and data — P1, M
- Article bodies **do** travel with the cached `Article` JSON (`bodyHtml` is part of the
  model and of `Article.toJson`), so a story that was in a cached scope reads offline —
  verified by `article_cache_test` and `offline_first_article_repository_test`. What is
  still missing: a story **never cached** (a deep link to an item outside the last rails)
  has no body because `byId` has no network fallback, and there is no per-article
  on-demand cache or stale-body refresh.
- Offline banner now renders on all four tabs (was For You only); "last updated"
  timestamps appear inside the banner.
- Data-saver image quality, video autoplay on Wi-Fi only, cache/storage screen with
  "clear images".
- Background refresh (e.g. WorkManager) so the feed is warm before the user opens it.

### B5. Platform integration — P1, M
- **Android home-screen widget** (A5) and app shortcuts ("Search", "Saved").
- **Verified App Links / Universal Links**: the manifest declares `slnews://article/<id>`
  and `https://slnews.app/article/<id>` with `autoVerify="false"` and no
  `assetlinks.json`/AASA checked in — shared links do not reliably open the app.
- Share target (receive links into the app), iOS notification/push capability, Android
  13 notification permission declaration, tablet and landscape layouts.

### B6. Account and personalisation — P1, S+M
- Sign-in exists (Clerk) and state sync exists. Missing: **account screen** (email, sign
  out, **delete account**, **export data**), password/email management, device list.
- Language and region is a static row ("English (Sierra Leone)") — not a setting.
- No recommendation feedback ("not interested", "more like this"), and rails are positional
  slices of one stream rather than a ranking.
- Author/publisher pages and following authors from the article kebab.

### B7. Trust, legal, compliance — P1, S+M
- No in-app **privacy policy / terms** (needed for store review once analytics or ads
  exist), no editorial standards or corrections page.
- Consent flow for analytics/ads (GDPR-style), ad labelling beyond the current "Ad" tag,
  frequency capping.
- **Content licensing**: the feed mixes scraped RSS with original reporting — attribution
  and rights review are a product/legal gap, not just code.
- Report flow exists; authoring side and response process do not.

### B8. Accessibility and localisation — P1, M
- English-only strings, no `l10n`/ARB files, no RTL support; Krio, Mende, Temne and French
  are the languages a Sierra Leonean product would consider.
- Screen-reader labels exist in places but there is no full TalkBack/VoiceOver audit;
  dynamic type at 200 % and contrast have not been verified; reduce-motion is implemented.

### B9. Monetisation — P2, L
No real ad SDK (in-house cards only), no sponsored-content model, no membership/support
tier, no consent management.

### B10. Reliability and observability — P1, M
- No crash reporting, no product analytics, no remote config/feature flags.
- No force-update gate and no staged rollout path.
- Testing is widget/unit + goldens (454 + 8); there are **no on-device integration or CI
  end-to-end tests**, which is how push, deep links and offline would normally be verified.

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

**Then (one to two weeks)**
7. Search v1 (B1): route, entry point, debounced query, results, recents.
8. Push v1 (B2): FCM/APNs, permission priming card (A4), token registration, deep link.
9. Top stories section page with hero header (A1).

**Later (multi-week, need decisions or content ops)**
10. Sports depth (A7): standings, league/team/game pages, league grouping.
11. Following mosaic (A3), ad formats (A6), widget + shortcuts (A5, B5).
12. Account deletion/export, privacy/terms, analytics + crash reporting, localisation.

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
