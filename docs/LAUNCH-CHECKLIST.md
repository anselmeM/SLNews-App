# Final pre-launch checklist — Android / Play Store

> **⚠️ Historical document — superseded, do not tick boxes here.**
> This is the code-2 era checklist (version `1.0.0+2`, 486 tests, repo at `b2d113d`).
> The current release line is
> [PLAY-RELEASE-CHECKLIST-1.0.0+61.md](PLAY-RELEASE-CHECKLIST-1.0.0+61.md)
> (version `1.0.0+61`, 640 functional tests). Kept for the deferred-items table
> (§F) and the reasoning; everything actionable has moved to the code-61 checklist.

Last updated: 18 October 2026 · repo `SLNews-App` at `b2d113d` · version `1.0.0+2`
**Upload session:** [PLAY-CONSOLE-UPLOAD-CHECKLIST.md](PLAY-CONSOLE-UPLOAD-CHECKLIST.md) — tick-box, tailored to the code-7 assets.

**Console walkthrough:** [PLAY-CONSOLE-WALKTHROUGH.md](PLAY-CONSOLE-WALKTHROUGH.md) — paste-ready fields in Play's order, plus the 30-minute device QA pass.

Companion documents: [PLAY-STORE-LAUNCH.md](PLAY-STORE-LAUNCH.md) (assessment),
[store/play/STORE-LISTING.md](../store/play/STORE-LISTING.md) (copy),
[store/play/DATA-SAFETY.md](../store/play/DATA-SAFETY.md) (console answers),
[store/play/legal/](../store/play/legal/) (policies).

Domain and mailboxes are **deferred**. Their impact is limited to the last mile: Play
needs a *reachable* privacy URL and contact address, which the live Vercel host and a
temporary mailbox cover. Everything else on this list is independent of the domain.

---

## A. Already done and verified (do not redo)

| Item | Evidence |
| --- | --- |
| Package id `com.slnews.mobile`, label `SLNews` | release APK/AAB badging |
| targetSdk/compileSdk 36, minSdk 26 (Android 8.0+, required by sentry_flutter 10) | `aapt2 dump badging` |
| 16 KB page-size alignment | `zipalign -c -P 16` passes |
| Release signing from `android/key.properties` (`CN=SLNews`) | APK + AAB signature verified |
| Play-ready AAB builds | `scripts/build_aab.ps1` → `SLNews-1.0.0-2.aab`, 62.4 MB, signature verified |
| CI builds the bundle with the keystore secret | `.github/workflows/build-apk.yml` (`bundle` job) |
| Launcher icon, adaptive + monochrome layers, splash | generated + verified inside the bundle |
| 486 tests, 9 golden renders, analyzer clean | `flutter test`, `flutter analyze` |
| Legal pages live: `/privacy`, `/terms`, `/delete-account` | sl-news.vercel.app, verified 2026-10-18 |
| `DELETE /api/mobile/v1/account` live | unauth call → `401 {"error":"Unauthorized"}` |
| Listing copy + data-safety answers drafted | store/play docs |
| Play icon, feature graphic, 7 screenshots, promo sheet | `store/play/` |

---

## B. Blockers — must be finished before the **internal-testing upload**

- [x] **1. Settings → About: Privacy policy and Terms of use rows.**
      Open the live URLs externally. *Owner: me (app).* Evidence: `legal_and_deletion_test`
      asserts both rows and that each opens its URL.
- [x] **2. Settings → SLNews account → Delete account.**
      Destructive confirmation, calls `DELETE /api/mobile/v1/account`, signs out, and keeps
      the account on any failure (ApiException or unexpected). *Owner: me (app).* Evidence:
      widget tests (confirm, cancel, success, server failure); one real deletion still to be
      done from an internal build with a live session.
- [ ] **3. Reachable contact address.**
      The pages currently publish `privacy@slnews.sl` / `contact@slnews.sl`, which do **not
      receive mail yet**. Either create the mailbox now, or temporarily point the pages and
      the Play listing at an address you monitor (a personal/project address is fine), then
      switch later. *Owner: you (or tell me the temporary address and I redeploy in minutes).*
- [ ] **4. Confirm the package id `com.slnews.mobile`.**
      Once the Play Console app is created it can never change. The `/download` page now
      points here; the alternate `com.slnews.app` was only ever in that link. *Owner: you.*
- [ ] **5. Record the content-rights decision.**
      Aggregated RSS headlines/images and publisher wordmarks currently have no permission
      basis. Decide before public launch: written permission / partner feeds / licensed
      wire / owned content, or an explicit accepted-risk note. *Owner: you. This is the
      single largest post-launch risk (IP complaint or takedown).*
- [x] **6. Crash reporting (Sentry).**
      Code is wired: `sentry_flutter` initialises only when `SENTRY_DSN` is present,
      reports uncaught errors plus a bootstrap failure, samples traces at 5 %, sends no
      PII/IP/screenshots, and the build scripts + CI pass the DSN. Remaining: create the
      Project `firstmiledevs/slnews-mobile` created, DSN in the CI secret, a direct event
      accepted (HTTP 200), and `/privacy` + Data-safety updated for diagnostics. Remaining
      human checks: disable IP storage, set a rate limit, and tap "Send test exception" on
      the verification build. *Owner: both.* See [OBSERVABILITY.md](OBSERVABILITY.md).
- [x] **7. Version bump for the store build.** `1.0.0+1` → `1.0.0+2` via
      `scripts/bump_version.ps1`. *Owner: me.*
- [x] **8. Rebuild the AAB after 1–2.** `SLNews-1.0.0-2.aab` — 62.4 MB, signature verified,
      16 KB alignment inherited from the build. A matching device APK was also built
      (`app-release.apk`, 65.7 MB). *Owner: me.*

---

## C. Play Console setup (calendar-bound, start now)

- [ ] **C1.** Developer account (US$25) + identity verification; organisation accounts
      need a D-U-N-S number and take longer. *Owner: you.*
- [ ] **C2.** Create the app: name `SLNews — Sierra Leone news`, package
      `com.slnews.mobile`, category **News & Magazines**, free. *Owner: you.*
- [ ] **C3.** Enrol **Play App Signing** with the existing upload key. Keep the keystore,
      `key.properties` and `ANDROID_KEYSTORE_BASE64` safe; losing the upload key is
      recoverable, losing a self-managed signing key is not (we are not using one). *Owner: you.*
- [ ] **C4.** Create an **internal testing** track and add tester emails; upload the AAB.
      *Owner: you.*
- [ ] **C5.** Fill **Data safety** from `store/play/DATA-SAFETY.md` §1. *Owner: you.*
- [ ] **C6.** Complete **Content rating** (answers in §3) and confirm the Teen/13+ result.
      *Owner: you.*
- [ ] **C7.** **Ads: yes** (§2), **target audience 13+/18+** (§4), **app access** with a
      demo account (§5 — create it in Clerk first), **financial features: no** (§6),
      **government app: no**, **export/encryption: standard TLS** (§9). *Owner: you.*
- [ ] **C8.** Store listing: paste copy from `STORE-LISTING.md`, upload icon, feature
      graphic and screenshots, set contact email, website and privacy URL
      (`https://sl-news.vercel.app/privacy` until the domain is live), add
      `https://sl-news.vercel.app/delete-account` where asked. *Owner: you.*
- [ ] **C9.** Countries: Sierra Leone first; expand after a stable week. *Owner: you.*
- [ ] **C10.** If the account is **personal**: closed test with **12 testers for 14
      continuous days** before production. Cannot be compressed — start the day the AAB is
      stable. *Owner: you.*

---

## D. QA gate — before promoting past internal testing

- [ ] **D1. Low-end device pass** — 2 GB RAM, Android 9–12, on 3G: cold start, feed
      scroll, article open, reel playback, search, offline.
- [ ] **D2. Offline pass** — airplane mode: feed opens from cache with the offline banner,
      a previously opened story shows its body, tabs explain themselves.
- [ ] **D3. Deletion pass** — real account: delete from Settings, confirm the row and
      Clerk identity are gone (sign-in no longer works), app is signed out with local state
      cleared.
- [ ] **D4. Legal links pass** — Privacy, Terms and Delete open from the app and from a
      browser with no app installed.
- [ ] **D5. Deep-link pass** — `adb shell am start -a android.intent.action.VIEW -d
      "slnews://article/<id>"` opens the reader. HTTPS App Links stay deferred with the
      domain.
- [ ] **D6. Notification-free sanity** — ~~ensure no screen claims notifications exist
      (copy check) since push has not shipped.~~ **Superseded:** push shipped in code 52+;
      audit notification copy against the shipped FCM behaviour instead
      ([PLAY-RELEASE-CHECKLIST-1.0.0+61.md](PLAY-RELEASE-CHECKLIST-1.0.0+61.md) §6).
- [ ] **D7. Accessibility spot check** — TalkBack on the four tabs, reader and reel;
      200 % text scale; no clipped controls.
- [ ] **D8. Real-device screenshots** — capture the seven listing screens into
      `store/play/captures/`, rerun `python tools/generate_store_assets.py`.
- [ ] **D9. Pre-launch report** — review Play's automated crawl findings; fix crashes and
      warnings before production.
- [ ] **D10. Read original pass** — a story opens the publisher page in-app, `aA` changes
      the page's text size, external links leave the app, back walks page history, and
      airplane mode shows the native-reader fallback.
- [ ] **D11. Financial disclaimer** — Stocks footer/reader shows attributable data and the
      "not investment advice" wording is reachable in Terms.

---

## E. Launch day and after

- [ ] **E1.** Promote to production with a **staged rollout (10 % → 50 % → 100 %)**, halting
      if the crash-free rate drops below 99.5 % or ratings flag a blocker.
- [ ] **E2.** Rollback plan: halt the rollout in Play Console; previous version stays
      available to existing users. No server migration is involved.
- [ ] **E3.** Watch for 72 h: crashes/ANRs, Play reviews, deletion requests, feed errors,
      market-data failures.
- [ ] **E4.** Publish a short "what's new" for the first release (draft in
      `STORE-LISTING.md`).
- [ ] **E5.** Add the release to `docs/FEATURE-GAPS.md` history and tag the mobile repo
      (`v1.0.0`).

---

## F. Deliberately deferred (not launch blockers for Android)

| Item | Why it can wait | What it affects |
| --- | --- | --- |
| Custom domain (`slnews.sl` or alternative) | Play accepts the live Vercel URL | listing URLs, HTTPS App Links, Clerk production domain; switch in one pass later |
| Mailboxes / aliases | a temporary monitored address satisfies Play | deletion-request handling; **must not be left on an unreachable address** |
| Push notifications (FCM/APNs) | not a Play requirement | biggest product gap; plan as v1.1 |
| Analytics | privacy policy currently promises none | product decisions; adding it changes Data-safety answers |
| iOS build | Android is the target | App Store checklist is a separate pass |
| Following mosaic, sports league pages, widget | reference-parity polish | post-launch roadmap |
| Real ad SDK / monetisation | in-house sponsored cards exist | revenue only |

---

## G. Sign-off

Ship the internal-testing upload when B1–B4, C1–C2 and C4 are done. Promote to production
only when B5–B8, C3, C5–C10 and **all of D** are checked, with the addresses in B3 working.

| Gate | Owner | Status |
| --- | --- | --- |
| Internal testing live | you | ⬜ |
| Production review submitted | you | ⬜ |
| Engineering blockers B1, B2, B7, B8 | me | ✅ |
| Rights decision B5 | you | ⬜ |
| Crash reporting B6 | both | ✅ |
