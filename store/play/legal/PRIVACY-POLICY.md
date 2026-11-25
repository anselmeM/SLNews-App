# SLNews — Privacy Policy (Android app)

**Last updated:** October 2026
**Applies to:** the SLNews Android application (`com.slnews.mobile`) and, where
stated, the SLNews website at https://sl-news.vercel.app.

> Draft for owner review. Filled-in facts come from the shipped code: Clerk for
> sign-in, the SLNews API/backend (Vercel + Neon) for sync, and no analytics, ad or
> crash-reporting SDK in the app. Placeholders in `{{ }}` are listed in
> [README.md](README.md#placeholders-to-fill).

## 1. Who we are

SLNews ("we", "our") is an independent news aggregation service for Sierra Leone.
For the purposes of data-protection law, the controller of your personal data is
**{{LEGAL ENTITY / OWNER NAME}}**, based in Sierra Leone.

Contact for anything in this policy, including deletion and access requests:
**privacy@slnews.sl**.

## 2. What this policy covers

This policy explains what the SLNews Android app does with your information. You can
read and browse SLNews **without an account**; an account is only needed to sync
saved stories, likes and follows between devices.

A note on the website: the SLNews website uses an advertising pixel for web
attribution. **The Android app does not contain that pixel, any analytics SDK, any
advertising SDK or any crash-reporting SDK.** The app never uses an advertising
identifier.

## 3. Information the app handles

| What | When | Where it goes |
| --- | --- | --- |
| **Email address and display name** | when you create an account or sign in | sent to Clerk (auth provider) and stored in our database |
| **Account identifier** (Clerk user id) | when you sign in | stored in our database |
| **Saved stories, likes, follows** | when you use those features while signed in | synced to our database so they appear on your other devices |
| **Reading preferences** (theme, text size, chosen location, alert toggles) | when you change them | stored on your device; signing in does not sync these settings |
| **Push-notification token** (FCM registration token) | only if you enable notifications | stored in our database against your account; deleted when notifications are turned off or you delete your account |
| **Technical request data** (IP address, app version, timestamps, error responses) | whenever the app talks to a server | processed by our hosting providers and visible to us in logs |
| **Anonymous sponsorship install ID** (random 32-character ID, not an advertising ID) and impression/tap events | when a sponsored card is shown or tapped | sent to our backend; only a keyed hash is stored, used for aggregate reach/frequency reporting; never linked to your account and never shared with advertisers |
| **Approximate weather location** (coordinates rounded to about 1 km) | only when you tap Use my location | used to fetch the forecast from Open-Meteo; not stored on our servers, not linked to your account, not used for advertising. You can switch back to the saved news location at any time. |
| **Locally cached content** (recent articles, images, preferences, the last weather place) | while you use the app | stored only on your device |

We do **not** store precise GPS location. If you opt into weather location, we use
approximate/rounded coordinates only to fetch your forecast (see the table above).
We do not collect contacts, calendar, SMS or call logs,
photos, camera or microphone input, health data, or your advertising identifier.

Search terms are matched against content already on your device; the app does not
send your queries to us as a search log.

**Personalized For You** uses follows, saved stories, likes and reading history
on your device to re-rank stories. These ranking signals are not sent to us, and
you can switch personalization off in Settings.

## 4. Why we use it

- **To run your account and sync your reading state** across devices (contract).
- **To show local weather when you opt in** (consent; you can switch it off at any
  time in Settings → Weather location).
- **To show the right local content and your preferences** (contract).
- **To send notifications you asked for** (consent; off by default and changeable at
  any time in Settings or in Android settings).
- **To keep the service working and secure** (legitimate interest): diagnosing
  errors, preventing abuse, capacity planning.
- **To comply with the law** where required.

We do not use your data for profiling, automated decision-making or targeted
advertising, and we do not sell it.

## 5. Service providers we use

| Provider | What it does | Data involved |
| --- | --- | --- |
| **Clerk** (clerk.com) | sign-in, session tokens | email, name, account id, authentication metadata |
| **Vercel Inc.** | hosts the SLNews API and website | request logs including IP address |
| **Neon** (database) | stores accounts and synced reading state | account data listed above |
| **Render** | runs our content-ingestion service | content requests, no reader accounts |
| **Google / YouTube** | plays embedded videos (privacy-enhanced `youtube-nocookie` player) | whatever Google collects in a web view; see Google's policy |
| **Google Translate** | only if you tap "Translate"; opens in your browser | the article URL |
| **Yahoo Finance** and **open.er-api.com** | market data requested by the app | your IP address, as with any web request |
| **Publishers** | we link to their stories | nothing beyond the click, then their own policy applies |

Our providers may process data outside Sierra Leone, including in the United States
and the European Union, under their standard contractual safeguards.

## 6. Advertising and sponsored content

Sponsored cards appear in the app next to editorial content and are always labelled
**Ad**. They are served by our own backend; the app contains no third-party ad SDK.
To report aggregate delivery to sponsors, the app sends a random anonymous install
ID with an impression/tap event; our server stores only a keyed hash and never shares
it with the advertiser. The ID is not an advertising ID, is not linked to your
account, and is not used to target ads. If you tap a sponsored card, the advertiser's
site opens in your browser and its own privacy policy applies.

## 7. How long we keep it

- **Account and synced reading state:** until you delete your account.
- **Deletion:** removing your account deletes the account record and the synced
  saved stories, likes and follows. Backups are purged on a rolling basis within
  **90 days**.
- **Anonymous sponsorship event hashes:** retained in aggregate delivery counters;
  the raw install ID is never stored server-side. Clearing app data or reinstalling
  generates a new ID; old hashes remain part of aggregate reporting.
- **Server logs:** kept by our hosting providers for their standard retention
  periods, then deleted.
- **On-device cache:** stays until you clear it in Settings, sign out, or uninstall
  the app — whichever comes first.

## 8. Your choices and rights

- **Delete your account and synced data** in the app: Settings → SLNews account →
  Delete account. If you cannot sign in, use https://sl-news.vercel.app/delete-account or
  email **privacy@slnews.sl**.
- **Access or export** your data: email us and we will send the account data we hold.
- **Correct** your name or email: Settings → SLNews account, or email us.
- **Use the app without an account:** you can read, search, save and like locally;
  sign out to stop syncing.
- **Notifications:** off by default; turn them off in Settings or Android settings.
- **Complain:** to us first, or to your local data-protection authority.

We answer verified requests within 30 days.

## 9. Children

SLNews is not directed to children under 13, and we do not knowingly collect their
personal data. If you believe a child has created an account, contact us and we will
delete it.

## 10. Security

Traffic between the app and our servers uses TLS. Sign-in tokens are managed by
Clerk and stored by the SDK in the platform's protected storage. Access to our
database is limited to the service and to maintainers who need it. No system is
perfect; on-device caches are not encrypted at rest, so anyone with access to your
unlocked device can read cached articles and preferences.

## 11. Changes

We will update this policy when the app's data practices change, and the "last
updated" date above will change with it. Material changes will be announced in the
app before they take effect.

## 12. Contact

**{{LEGAL ENTITY / OWNER NAME}}**
Sierra Leone
Email: **privacy@slnews.sl**


**Push notifications:** delivered through Firebase Cloud Messaging (Google). The
app registers a device token with our server; it is used only to deliver alerts the
reader enabled, and is removed on sign-out or when invalid.
