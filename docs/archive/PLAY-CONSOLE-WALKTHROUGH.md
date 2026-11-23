# Play Console walkthrough — code 6 to production

Paste-ready fields, in the order Play asks for them. Companion docs:
[LAUNCH-CHECKLIST.md](LAUNCH-CHECKLIST.md) (gates), [PLAY-STORE-LAUNCH.md](../PLAY-STORE-LAUNCH.md)
(assessment), `store/play/STORE-LISTING.md` (copy), `store/play/DATA-SAFETY.md` (answers).

**Build to upload:** `build/dist/SLNews-1.0.0-6.aab`
· version `1.0.0` code **6** · 66.7 MB ·
sha256 `203e92e8d39b929f4351488005378a40a3dc8e6805e969e1472e3f12e529373c`
· signed `CN=SLNews` · package `com.slnews.mobile` · minSdk 26 · targetSdk 36.

---

## 0. Have these in hand first

| Thing | Where |
| --- | --- |
| Google account you want to own the app | — |
| Upload keystore + passwords | `android/key.properties`, `android/slnews-release.jks` (and the CI secrets) |
| A **demo account** for reviewers | create one in Clerk, e.g. `reviewer+play@…` with a known password |
| Reachable contact email | `privacy@slnews.sl` once the mailbox exists; otherwise a temporary monitored address |
| Privacy + deletion URLs | `https://sl-news.vercel.app/privacy`, `/delete-account` (switch to `slnews.sl` once live) |

---

## 1. Developer account (once)

1. <https://play.google.com/console> → **Create developer account** → **US$25**.
2. Choose **Personal** or **Organisation** (organisation needs a D-U-N-S number and takes
   days; personal needs identity verification and imposes the 12 × 14-day closed test).
3. Complete **identity verification** — this can take 24–48 h. Start it before anything else.

## 2. Create the app

| Field | Value |
| --- | --- |
| App name | `SLNews — Sierra Leone news` |
| Default language | English (United States) |
| App or game | **App** |
| Free or paid | **Free** |
| Declarations | Accept the developer programme policies |

Package name: **`com.slnews.mobile`** — permanent after this point.

## 3. Play App Signing

**Release → Setup → App signing** → *Use Play App Signing* → upload the existing keystore
(the one in `android/slnews-release.jks`) as the **upload key**. Play holds the app-signing
key. Keep the upload keystore and passwords backed up; losing the upload key is
recoverable via support, losing a self-managed signing key is not.

## 4. Internal testing upload (first)

1. **Testing → Internal testing → Create new release**.
2. Upload `SLNews-1.0.0-6.aab`.
3. Release name: `1.0.0 (6) — first internal build`.
4. Release notes: *“First internal build: native reader + Read original, live weather,
   briefing, Sports standings/league/team pages, Following mosaic and manage screens,
   account deletion, crash reporting.”*
5. Add tester emails (your own first), **Save → Review release → Start rollout**.
6. Install from the Play internal-testing link on a device.

## 5. App content (all required before closed testing)

### 5.1 Privacy policy
`https://sl-news.vercel.app/privacy` (switch to `https://slnews.sl/privacy` when DNS is live).
The page must be publicly reachable without login — it is.

### 5.2 Ads
**Yes**, the app contains ads. Sponsored cards are served by our backend and labelled
“Ad”; no third-party ad SDK.

### 5.3 App access
Choose **“All functionality is available without special access”** — *except* you must
still provide credentials for the optional account features Play asks about. Answer:
**“Some features require login”**, and give the demo account:
- Username: the reviewer email
- Password: set it
- Instructions: *“Sign-in is optional. To test the account features, sign in from
  Settings → SLNews account, then use Delete account there. Reading, search and saving
  work without signing in.”*

### 5.4 Content rating (IARC questionnaire)
Category **News**; violence/sex/language/drugs **No**; user-generated content **No**;
shares location **No**; digital purchases **No**; unrestricted web access **Yes** — the
Read original mode shows publisher pages, so answer honestly. Expected outcome **Teen**.

### 5.5 Target audience
**13+** (not designed for children). Do not opt into the Families programme.

### 5.6 News app declaration
Declare **News**. Sources are named per story, attribution and original links are shown,
and the financial data carries a “not investment advice” disclaimer in Terms.

### 5.7 Data safety
Answer from `store/play/DATA-SAFETY.md` §1. Summary:
- Collects **email, name, user IDs** (optional, only if the reader signs in) — account
  management, app functionality; encrypted in transit; deletable.
- Collects **saved stories, likes, follows** (optional) — sync.
- Collects **Diagnostics: crash logs + sampled performance** (automatic) — app
  functionality/diagnostics; not shared; 90-day retention at Sentry.
- **No** location, contacts, camera, mic, photos, health, financial info, web browsing
  history, app-interaction analytics, device IDs or advertising ID.
- Data deletion: **Yes** — in-app plus `https://sl-news.vercel.app/delete-account`.

### 5.8 Other declarations
Government app **No** · financial features **No** (market data is informational) ·
health **No** · encryption/export: uses standard TLS (exempt) · account deletion URL yes.

## 6. Store listing

Paste from `store/play/STORE-LISTING.md`:

| Field | Value |
| --- | --- |
| App name | `SLNews — Sierra Leone news` (27 chars) |
| Short description | `Sierra Leone news, sports, markets and local voices in one feed.` (73) |
| Full description | see STORE-LISTING (≈2 450 chars) |
| App icon | `store/play/icon-512.png` (512×512) |
| Feature graphic | `store/play/feature-graphic-1024x500.png` |
| Phone screenshots | `store/play/screenshots/phone-0*.png` (1080×1920, 7) |
| Website | `https://sl-news.vercel.app` (then `https://slnews.sl`) |
| Email | `privacy@slnews.sl` (or the temporary monitored address) |
| Privacy policy | as §5.1 |
| Category | News & Magazines · Tags: News, Sierra Leone, Sports |
| Countries | Sierra Leone first; add diaspora markets after a stable week |

## 7. Closed testing (the 14-day clock)

1. **Testing → Closed testing → Create track**, add the same AAB.
2. Tester list: 12 people, 12 **distinct Google accounts**; share the opt-in URL.
3. They must **install and keep the app installed, and open it** during the window —
   Google measures retained testers, not invited ones.
4. Collect feedback via the Play “App feedback” channel and your own form.
5. Run the **Pre-launch report** (Play crawls the app automatically) and fix crashes or
   warnings it surfaces.
6. While it ticks: finish the mailbox, Firebase/push, and the sponsor measurement tail.

Personal accounts: apply for **production access** after the 14 days with a short
description of what testers did and what changed.

## 8. Production

1. **Production → Create new release** (same AAB, or a newer code if anything changed).
2. **Staged rollout**: 10 % → 50 % → 100 %, halting if the crash-free rate drops below
   99.5 % in Sentry or the Play vitals report.
3. Rollback = halt the rollout; the previous version stays available.
4. Watch for 72 h: crashes/ANRs, reviews, deletion requests, feed errors.

---

## Appendix A — 30-minute device QA pass

Install the internal-testing build on a real phone (ideally two: one low-end, one current).

| # | Action | Expected |
| --- | --- | --- |
| 1 | Cold start on airplane mode | Feed renders from cache, offline banner shows |
| 2 | For You | Weather chip shows today's Open-Meteo reading; briefing card with 3 headlines; mosaic rail below |
| 3 | Open a story | Native reader, byline, reading-time, progress hairline |
| 4 | Globe icon → Read original | Publisher page in-app; `aA` resizes text; Reader returns; external link leaves the app |
| 5 | Read original offline | “You're offline … Read in SLNews reader” fallback |
| 6 | Save → Saved stories | Story listed; offline note visible; opens offline |
| 7 | Sports | Scoreboard, standings card, league page, team page, fixtures |
| 8 | Following | Account card, manage sources/topics, search + follow |
| 9 | Search | Typing finds stories; empty state sane |
| 10 | Settings | Theme, text size, privacy/terms open, Send test exception (verification build) |
| 11 | Account (signed in) | Email shown; Sign out works |
| 12 | Delete account (throwaway account) | Confirmation → deleted → signed out |
| 13 | Rotation / dark mode / 200 % text | No clipping, no overflow |
| 14 | Background/foreground, then kill + reopen | State survives |
| 15 | Sentry | Any crash appears in `firstmiledevs/slnews-mobile` |

## Appendix B — common news-app rejections and the fix

| Rejection | Cause | Fix |
| --- | --- | --- |
| Missing account deletion | App creates accounts without a deletion path | Already shipped (in-app + web page) |
| Privacy policy mismatch | Policy claims differ from Data safety | Keep both in sync; Sentry and ads are declared |
| Misleading ads | Sponsored cards not labelled | Every sold unit renders the `Ad` label and disclosure |
| Broken links / crash on WebView | Publisher blocks the in-app browser | Fallback to native reader; error reported to Sentry |
| Copyrighted content complaint | Aggregated publisher content | Rights decision (owner) + attribution + takedown address |
| Unreachable contact | Placeholder email in listing/policy | Real mailbox before submission |
