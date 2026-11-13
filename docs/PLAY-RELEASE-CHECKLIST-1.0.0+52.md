# SLNews — Play Console release checklist (1.0.0, code 52)

Built from `master` (`e41010f`) on 2026-11-12. This is the current checklist;
`PLAY-CONSOLE-UPLOAD-CHECKLIST.md` describes an older code-7 build and is kept
only for history.

## Release artefact

| Field | Value |
| --- | --- |
| Package | `com.slnews.mobile` |
| Version | `1.0.0` (versionCode **52**) |
| Min / target SDK | 26 / **36** (compileSdk 36) |
| AAB file | `C:\Users\amotc\Downloads\SLNews-1.0.0+52.aab` |
| Size | 68.3 MB |
| SHA-256 | `9E6771601E91352815D1B38DF989A79B3477F92094A4B77D342FD199861CECB7` |
| Signing | release keystore, JAR verified (`jarsigner -verify`) |
| Release defines | `SLNEWS_SCOREBOARD_URL`, `SLNEWS_IMAGE_PROXY`, `SLNEWS_WEB_URL`, Sentry DSN, TheSportsDB |
| Upload key | `android/slnews-release.jks` + `android/key.properties` (never commit) |

Re-verify before uploading:

```powershell
Get-FileHash "$env:USERPROFILE\Downloads\SLNews-1.0.0+52.aab" -Algorithm SHA256
jarsigner -verify "$env:USERPROFILE\Downloads\SLNews-1.0.0+52.aab"
```

## 0. Pre-flight (owner: you)

- [ ] **Back up the upload keystore** (`android/slnews-release.jks`) and its
      passwords outside the repo and outside this laptop (password manager +
      offline copy). Losing it blocks every future upload unless Play App
      Signing key reset is requested.
- [ ] Play Console developer account is **verified** (identity verification can
      take 24–48 h).
- [ ] Decide **personal vs organisation** account. Personal accounts are subject
      to the closed-testing requirement; confirm the current rule in the
      console before planning dates.
- [ ] **Privacy mailbox** exists and is monitored. Policy currently lists
      `privacy@slnews.sl`; if that mailbox is not live, use a monitored address
      and update `https://sl-news.vercel.app/privacy` first.
- [ ] Create the **reviewer demo account** in Clerk (email + password you
      control; complete onboarding so For You renders).
- [ ] Confirm URLs are live logged-out:
      `https://sl-news.vercel.app/privacy`,
      `https://sl-news.vercel.app/delete-account`,
      `https://sl-news.vercel.app/terms`.
- [ ] Content rights for aggregated headlines: you have permission/attribution
      policy for every publisher source, and the app always links to the
      original.
- [ ] A **live campaign** is active for ad QA (the current feed currently has
      none). Create a `feed` campaign in `/admin/sponsorships/new`, with an
      uploaded image, and stop it after QA.

## 1. Create the app / Play App Signing

- [ ] Play Console → **Create app**: name `SLNews`, default language English,
      App, Free.
- [ ] Package name **`com.slnews.mobile`** (permanent).
- [ ] **Release → Setup → App signing** → **Play App Signing** → upload the
      existing keystore as the **upload key**.
- [ ] Keep Google's generated app-signing certificate backup.

## 2. Internal testing (first install proof)

- [ ] Testing → **Internal testing** → **Create new release**.
- [ ] Upload `SLNews-1.0.0+52.aab`.
- [ ] Release name: `1.0.0 (52) — live sports news/standings, ads, onboarding, push`.
- [ ] Release notes:
      `First-run topic/location picker, sponsored cards with image creatives, push segmentation by followed topics, offline reading polish.`
- [ ] Add your Google account as a tester; roll out.
- [ ] Install from the opt-in link on a physical device, launch once, sign in,
      finish onboarding, confirm For You loads.

Optional local install proof from the AAB:

```powershell
# bundletool: https://github.com/google/bundletool/releases
java -jar bundletool.jar build-apks --bundle="$env:USERPROFILE\Downloads\SLNews-1.0.0+52.aab" --output=slnews.apks --mode=universal
java -jar bundletool.jar install-apks --apks=slnews.apks
```

## 3. App content (all required before closed testing)

### Privacy policy
- [ ] `https://sl-news.vercel.app/privacy` (verified 200).

### Ads
- [ ] **Yes, contains ads.** Sponsored cards are first-party and labelled `AD`;
      no third-party ad SDK. Data safety does not list an advertising ID.

### App access
- [ ] **All or some functionality is restricted** → provide the demo account.
      Sign-in is optional, but sync/saved/follows need it.

### Content rating (IARC)
- [ ] Category **News**.
- [ ] Violence/sex/language/drugs: **No**.
- [ ] User-generated content/social: **No** (no comments/uploads).
- [ ] Shares location: **No** (city is chosen manually).
- [ ] Digital purchases: **No**.
- [ ] Unrestricted web access: **Yes** (Read original opens publisher pages).
- [ ] Expected rating: **Teen**.

### Target audience
- [ ] **13+**, not child-directed; do not enrol in Families.

### News app declaration
- [ ] Declare **News**. Every story names its publisher and offers Read
      original; market data is informational, not investment advice.

### Data safety (align with the app; do not over-declare)
- [ ] **Account**: email/name/user ID for optional sign-in — collected,
      encrypted in transit, deletable, used for account management/app
      functionality.
- [ ] **App activity**: saved stories, follows, notification prefs — optional,
      synced to the account, deletable.
- [ ] **Device/push**: FCM token/device registration for notifications.
- [ ] **Diagnostics**: crash logs and sampled performance (Sentry), not shared
      for advertising, 90-day retention.
- [ ] **Not collected**: location, contacts, camera, microphone, photos,
      health, financial info, web browsing history, advertising ID.
- [ ] **Deletion**: in-app plus `https://sl-news.vercel.app/delete-account`
      (verified 200).

### Other declarations
- [ ] No government affiliation, no financial products, no health features.
- [ ] Confirm the app does not request SMS/call-log/background-location
      permissions (manifest currently: INTERNET, ACCESS_NETWORK_STATE,
      POST_NOTIFICATIONS only).

## 4. Store listing

- [ ] App icon **512×512** PNG (32-bit, no alpha).
- [ ] Feature graphic **1024×500**.
- [ ] Phone screenshots **2–8** (For You, article, sports, onboarding, ad card).
- [ ] Short description ≤ 80 chars; full description ≤ 4000.
- [ ] Category **News & Magazines**; tags; contact email + website.
- [ ] Privacy policy URL; content-rights acknowledgement.

## 5. Closed testing → production

- [ ] Create a **Closed testing** track, add testers, roll out code 52.
- [ ] Keep the track active for the period required by your account type
      (personal accounts: confirm the current tester count/duration in the
      console; historically 12 testers / 14 days).
- [ ] Collect tester feedback; fix blockers with a higher versionCode.
- [ ] Apply for production access if the console requires it.
- [ ] Production release: **staged rollout 10–20%**, watch crash-free rate and
      ANRs for 24–48 h, then ramp.
- [ ] Halt criteria: crash-free < 99%, ad/image failures, push failures,
      sign-in/onboarding blockers.

## 6. Device QA before production

- [ ] Fresh install → onboarding (topics + city) → For You.
- [ ] Sold ad card renders headline, image, `AD` label, disclosure; tap opens
      CTA; admin impressions/taps increase.
- [ ] No active campaign → house ads still render (seed fallback).
- [ ] Push: permission prompt, breaking/topic segment arrives, toggle off stops.
- [ ] Offline: cached For You/article open; retry when back online.
- [ ] Deep links: `slnews://article/<id>` and the https App Link open the
      article. Verify `https://sl-news.vercel.app/.well-known/assetlinks.json`
      matches the Play signing certificate before relying on App Links.
- [ ] Account deletion completes; data disappears after reinstall/sign-in.
- [ ] No crashes in Sentry for the release; cold start < 3 s on a mid-range
      device.

## Known gaps / risks

1. **Privacy mailbox** `privacy@slnews.sl` may not exist yet — fix before
   submission or use a monitored address.
2. **HTTPS App Links** are declared; `assetlinks.json` returns 200 on Vercel,
   but confirm the certificate fingerprint matches the Play app-signing cert
   (not just the upload key).
3. **Ads QA needs a live campaign**; production currently has 0 active feed
   campaigns.
4. **AAB size 68.3 MB** — Play limit is 200 MB for base bundles, so fine, but
   first-install size matters for Sierra Leone data costs; consider an asset
   bundle later if it grows.
5. **Version code 52 must never be reused**; every upload needs a higher code.
6. Closed-testing requirements vary by account type/date — confirm in Console.

## Release notes (paste)

```
SLNews 1.0.0
• First-run topic and city picker personalises For You immediately
• Sponsored cards support image creatives and are always labelled Ad
• Push notifications segmented by followed topics/teams, with toggles
• Faster image loading, offline reading fixes and crash reporting
```

## Code 44 notes

- Adds live ESPN team news for covered teams (Lakers) and NBA/EPL standings.
- Lakers fixtures match the live scoreboard team name.
- Standings appear when following the team even without following its league.

## Code 45 notes

- Sports tab rebuilt to the Samsung reference: two-up score cards, larger Following crests, large ad, Top stories feed, league blocks with Follow + scores + hero story + More stories, dark surface.

## Code 46 notes

- Standings removed from the Sports feed and owned by the inner league page; tapping a league header or its stories opens that page.

## Code 47 notes

- Sports feed groups every major league present in the scoreboard: NBA, NFL, MLB, NHL, Premier League, Sierra Leone Premier League, AFCON Qualifier, each with its own icon, colour, scores, hero story and More link.
- Scoreboard limit raised from 8 to 40 so later leagues are not silently cut off; seed SLPL/AFCON fixtures are preserved alongside live leagues.
- ESPN standings added for NFL, NHL and MLB; NBA/EPL already live; SLPL/AFCON fall back to seed tables.

## Code 48 notes

- League blocks use strict league/team cues; the generic sports feed is no longer stuffed into every league. A block shows only score cards when no story clearly belongs to it.
- Inner league page Latest stories uses the same strict filter.

## Code 49 notes

- League blocks use league-specific feeds: Yahoo Sports RSS for NBA/NFL/MLB/NHL, Google News for Premier League/Sierra Leone Premier League/AFCON; the strict league filter is applied again after parsing.
- External league stories open on the publisher, not in the local reader.

## Code 50 notes

- League sections are built through SliverList.builder and fetch their league feed only when they approach the viewport; the initial Sports load no longer requests all seven feeds.

## Code 51 notes

- State-machine hardening: unknown auth splash, onboarding write-error handling, bounded sync retry, ad impression dedupe and league-feed refresh.

## Code 52 notes

- FCM applied topics persisted/reconciled across restarts; foreground resume refresh clears sticky offline; 603 tests pass.
