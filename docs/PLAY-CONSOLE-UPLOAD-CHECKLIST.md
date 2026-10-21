# Play Console upload — tick-box session

Tailored to the **current assets** (version `1.0.0+7`, 21 Oct 2026). Companion docs:
[PLAY-CONSOLE-WALKTHROUGH.md](PLAY-CONSOLE-WALKTHROUGH.md) (explanations),
`store/play/STORE-LISTING.md` (full description copy),
`store/play/DATA-SAFETY.md` (Data-safety answers), `store/play/legal/`.

**Upload artifact:** `build/dist/SLNews-1.0.0-7.aab`
· 66.7 MB · sha256 `d3b0acdab0a04a51bd886a91ef7387bed25544ac6001330619e31419214f1622`
· signed `CN=SLNews` · version **`1.0.0` (code 7)** · package `com.slnews.mobile`
· minSdk 26 · targetSdk 36 · Play App Signing via the existing upload key.

Do not rebuild before uploading unless something in the app changes: **a new build needs code 8.**

---

## Session plan (~60–90 minutes, excluding Google's verification wait)

| Block | Time | Output |
| --- | --- | --- |
| A. Pre-flight | 10 min | keys confirmed, demo account ready, URLs reachable |
| B. Account + app creation | 15 min | app exists, signing configured |
| C. Internal-testing upload | 10 min | code 7 installable from Play |
| D. App content forms | 25 min | submission unblocked |
| E. Store listing | 15 min | listing complete |
| F. Closed testing + application | 10 min | 14-day clock started |

---

## A. Pre-flight

- [ ] Upload keystore backed up **outside** the repo: `android/slnews-release.jks` + the passwords in `android/key.properties`.
- [ ] Keystore passwords recorded somewhere safe (password manager).
- [ ] Confirm the build: `flutter build appbundle --release` was last run as `1.0.0+7`; `pubspec.yaml` says `version: 1.0.0+7`.
- [ ] Copy the AAB somewhere stable and verify its hash:
  ```powershell
  Get-FileHash .\build\dist\SLNews-1.0.0-7.aab -Algorithm SHA256
  # D3B0ACDAB0A04A51BD886A91EF7387BED25544AC6001330619E31419214F1622
  ```
- [ ] **Create the reviewer demo account** in Clerk (email + password you control, marked as a test user). Play will ask for credentials because the app has optional sign-in.
- [ ] Privacy / deletion URLs reachable, logged out:
  - [ ] `https://sl-news.vercel.app/privacy`
  - [ ] `https://sl-news.vercel.app/terms`
  - [ ] `https://sl-news.vercel.app/delete-account`
- [ ] Contact email exists and can receive mail: `privacy@slnews.sl` **(still pending — see Known gaps; use a monitored address until the domain mailbox exists, and update the listing + policy when it lands)**.
- [ ] Play Console developer account is **verified** (identity verification can take 24–48 h; start it before this session if not done).
- [ ] Decide **personal vs organisation** account. Personal accounts require the 12-tester / 14-day closed test before production.

## B. Create the app and configure signing

- [ ] Play Console → **Create app**.
  - App name: `SLNews — Sierra Leone news`
  - Default language: English (United States)
  - App or game: **App**
  - Free or paid: **Free**
- [ ] Accept the developer programme policies.
- [ ] Confirm package name is shown as **`com.slnews.mobile`** (permanent).
- [ ] **Release → Setup → App signing** → choose **Play App Signing** → upload the existing keystore as the **upload key**.
- [ ] Keep the generated certificate/keys backup file.

## C. Internal-testing upload (first install proof)

- [ ] Testing → **Internal testing** → **Create new release**.
- [ ] Upload `SLNews-1.0.0-7.aab`.
- [ ] Release name: `1.0.0 (7) — first internal build`.
- [ ] Release notes (paste):
  > First internal build: native reader with Read original, live weather, daily briefing, sports standings/league/team pages, Following mosaic and manage screens, search, saved stories offline, account deletion, crash reporting.
- [ ] Add your own Google account as a tester.
- [ ] Review → **Start rollout to Internal testing**.
- [ ] Install from the opt-in link on a real phone and open it once (this also warms Sentry release mapping).

## D. App content forms (all required)

### D1. Privacy policy
- [ ] URL: `https://sl-news.vercel.app/privacy`

### D2. Ads
- [ ] **Yes**, the app contains ads. (Sponsored cards are served by SLNews and labelled “Ad”; no third-party ad SDK.)

### D3. App access
- [ ] Select **All or some functionality is restricted** → add the demo account.
  - Username: `<reviewer demo email>`
  - Password: `<demo password>`
  - Instructions (paste):
    > Sign-in is optional. Reading, search, saving and following work without an account. To test account features, sign in from Settings → SLNews account, then use Delete account there.

### D4. Content rating (IARC questionnaire)
- [ ] Category: **News**
- [ ] Violence / sex / language / controlled substances: **No**
- [ ] User-generated content / social features: **No** (no comments or uploads in this release)
- [ ] Shares location: **No** (weather uses a chosen city, not device GPS)
- [ ] Digital purchases: **No**
- [ ] Unrestricted web access: **Yes** (Read original opens publisher pages in an in-app browser)
- [ ] Expected rating: **Teen**; no additional declarations.

### D5. Target audience
- [ ] Age group **13+** (not child-directed).
- [ ] Do **not** enrol in Families.

### D6. News app declaration
- [ ] Declare **News**. Attribution: every story names its publisher and offers Read original; market data is informational, not investment advice.

### D7. Data safety
Answer from `store/play/DATA-SAFETY.md` §1. Summary to enter:
- [ ] **Collects** email/name/user IDs — only for optional sign-in → *Account management*, *App functionality*; encrypted in transit; **deletable**.
- [ ] **Collects** saved stories / likes / follows — optional, sync.
- [ ] **Collects Diagnostics**: crash logs + sampled performance → *App functionality*, *Diagnostics*; not shared; **90-day retention** at Sentry.
- [ ] **Does not collect/ share**: location, contacts, camera, microphone, photos, health, financial info, web browsing history, app-interaction analytics, device/advertising ID.
- [ ] Data deletion: **Yes** — in-app plus `https://sl-news.vercel.app/delete-account`.
- [ ] Confirm the form matches the current app (no AdMob, no analytics SDK, no push yet).

### D8. Other declarations
- [ ] Government app: **No**
- [ ] Financial features: **No** (market prices are informational)
- [ ] Health: **No**
- [ ] Encryption/export: standard TLS (exempt)
- [ ] Account deletion URL: `https://sl-news.vercel.app/delete-account`

## E. Store listing

| Field | Value / source |
| --- | --- |
| App name | `SLNews — Sierra Leone news` |
| Short description | `Sierra Leone news, sports, markets and local voices in one feed.` |
| Full description | `store/play/STORE-LISTING.md` (full copy block) |
| App icon | `store/play/icon-512.png` (512×512) |
| Feature graphic | `store/play/feature-graphic-1024x500.png` |
| Phone screenshots | `store/play/screenshots/phone-01 … phone-07` (1080×1920) |
| Website | `https://sl-news.vercel.app` (switch to `https://slnews.sl` when live) |
| Email | `privacy@slnews.sl` (or the temporary monitored address) |
| Privacy policy | `https://sl-news.vercel.app/privacy` |
| Category | News & Magazines |
| Tags | News, Sierra Leone, Sports |
| Countries | Sierra Leone first; add diaspora markets after a stable week |

- [ ] Upload icon, feature graphic, all seven screenshots (order: For You, News, Sports, Article, Section, Search, Following).
- [ ] Paste full description; check character count and no unsupported claims.
- [ ] Set contact details and website.

## F. Closed testing (the 14-day clock)

- [ ] Testing → **Closed testing** → **Create track**; add the same AAB (code 7).
- [ ] Tester list: **12 distinct Google accounts** (own numbers + colleagues; not aliases of one account).
- [ ] Share the opt-in URL; ask each tester to **install and open** the app, and keep it installed.
- [ ] Enable **App feedback** channel; collect feedback in a simple sheet.
- [ ] Run the **Pre-launch report** and fix anything it reports (crashes, ANRs, accessibility warnings).
- [ ] After 14 continuous days, apply for **Production access** (personal accounts) with one paragraph on what testers did and what changed.

## G. Production rollout

- [ ] Production → **Create new release** with code 7 (or code 8 if anything changed after testing).
- [ ] **Staged rollout:** 10 % → 50 % → 100 %.
- [ ] Halt threshold: crash-free rate below 99.5 % (Play vitals or Sentry `slnews-mobile`).
- [ ] Watch for 72 h: crashes/ANRs, reviews, deletion requests, feed errors.

## H. Post-upload verification (on the installed build)

- [ ] Cold start with airplane mode → cached feed + offline banner.
- [ ] For You: weather chip, briefing card, topic mosaic.
- [ ] Open a story → native reader → globe icon → Read original → back.
- [ ] Read original while offline → “Read in SLNews reader” fallback.
- [ ] Save a story → Saved stories → opens offline.
- [ ] Sports: scoreboard, standings, league page, team page.
- [ ] Following: account card, manage sources/topics.
- [ ] Search returns stories and videos.
- [ ] Settings: theme, text size, privacy/terms open.
- [ ] Signed-in account → sign out works.
- [ ] Delete account with a throwaway account → confirmation → signed out.
- [ ] Sponsored card appears labelled **Ad** (seed a campaign from `/admin/sponsorships`); tap counts.
- [ ] Any crash appears in Sentry `firstmiledevs/slnews-mobile`.

## I. Rollback and safety

- [ ] Rollback = **halt the rollout**; the previous version stays live.
- [ ] Never reuse a version code; every upload needs a new `+N`.
- [ ] Never delete or regenerate the upload keystore.
- [ ] Do not remove the `/delete-account` or `/privacy` pages while the listing is live — reviewers check them.

## Known gaps before you press submit

- [ ] **Mailbox**: `privacy@slnews.sl` does not exist yet. Use a monitored address now, and update listing + policy when the domain mailbox is live. (This is the only listing value still placeholder.)
- [ ] **Demo reviewer account**: must be created in Clerk before D3 can be completed.
- [ ] **Content rights decision**: how aggregated publisher content is licensed/attributed (owner decision; not a Play form, but a real launch risk).
- [ ] **Custom domain**: optional for submission; required before App Links and a professional contact address.
- [ ] **Do not upload the web repo changes** — the AAB is unaffected by marketing-site work.
