# Play Console declarations — answer sheet

Copy these answers into Play Console. They describe the **Android app as built**
(`com.slnews.mobile`, version 1.0.0+1), not the website: the app has no analytics,
advertising or crash-reporting SDK, and no advertising identifier.

> Draft for owner review. Placeholders in `{{ }}` are listed in
> [legal/README.md](legal/README.md#placeholders-to-fill).

## 1. App content → Data safety

### Does your app collect or share any required user data types? **Yes**

Only account data, and only when the person chooses to sign in.

| Category | Data type | Collected | Shared | Optional? | Purpose | Deletion |
| --- | --- | --- | --- | --- | --- | --- |
| Personal info | Email address | Yes | No | Yes — account is optional | Account management | Yes |
| Personal info | Name | Yes | No | Yes | Account management | Yes |
| Personal info | User IDs | Yes | No | Yes | Account management, app functionality (sync) | Yes |
| App activity | Other in-app actions (saved stories, likes, follows) | Yes | No | Yes | App functionality (sync across devices) | Yes |

Everything else: **not collected**. No location, no financial info, no health, no
messages, no photos or videos, no audio, no files, no contacts, no calendar, no web
browsing history, no app interactions analytics, no crash logs, no device or other IDs
today.

**Security practices**

- Data is encrypted in transit: **Yes**.
- Users can request that data be deleted: **Yes** — in-app path plus
  https://sl-news.vercel.app/delete-account.
- Independent security review: **No**.
- Committed to Play Families policy: **No** (not directed to children).

**Notes for the reviewer**

- Browsing, search, saving and liking work without an account; data is then local to
  the device and never transmitted.
- Sign-in is handled by Clerk; the app stores only the resulting session on device.
- Sponsored cards are served by our own backend; no ad SDK and no data sharing with
  advertisers.

### When push notifications ship, add

- **Device or other IDs → Device or other IDs**: collected, optional (only when
  notifications are enabled), purpose "App functionality (notifications)", deletion yes.
- **Diagnostics → Crash logs** only if a crash-reporting SDK is added, with its
  vendor named in the privacy policy.

## 2. App content → Ads

- **Does your app contain ads? Yes** — sponsored cards labelled "Ad" are served from
  our backend. No third-party ad SDK.
- Ads are not targeted using personal data.

## 3. App content → Content rating (IARC questionnaire)

| Question | Answer |
| --- | --- |
| Category | News |
| Violence (real-world, references) | Yes — news reporting can reference violence; infrequent/mild |
| Blood, gore, sexual content, nudity | No |
| Profanity | No |
| Drugs, alcohol, tobacco references | No |
| Gambling, simulated gambling | No |
| User-generated content or user-to-user interaction | No |
| Shares user's location | No |
| Allows users to purchase digital goods | No |
| Contains ads | Yes (labelled sponsored cards) |

Expected outcome: **Teen / 13+** (news with real-world violence references). Accept the
IARC result rather than arguing it down; it is usually right for a news aggregator.

## 4. App content → Target audience

- Age groups: **13–17 and 18+**.
- Designed for children: **No**; not enrolled in Designed for Families.
- Appeal to children: **No**.

## 5. App content → App access

**All content is available without signing in.** Sign-in is optional and only adds
cross-device sync of saved stories, likes and follows.

Provide these credentials anyway, in case review wants to see the synced state:
`{{DEMO ACCOUNT EMAIL}}` / `{{DEMO ACCOUNT PASSWORD}}`.

## 6. App content → Financial features

The app **displays** third-party market index quotes for information. It does not
provide financial services, advice, trading, payments or lending.

- If Play asks whether the app provides financial services: **No**.
- If asked about financial data display: state "informational market data with
  attribution and a not-investment-advice disclaimer" (the app's Stocks footer and
  Terms §5 cover this).

## 7. App content → Government apps / News app declarations

- Government app: **No**.
- News app: **Yes** — an aggregator that links to original reporting, with publisher
  attribution; it does not claim to be the publisher (see Legal/rights item in the
  launch doc).

## 8. Permissions

| Permission | Why it is declared |
| --- | --- |
| `INTERNET` | fetching news, images, market data, sync |
| `ACCESS_NETWORK_STATE` | offline banner and cache decisions |
| `USE_BIOMETRIC`, `USE_FINGERPRINT`, `USE_CREDENTIALS`, `CREDENTIAL_MANAGER_SET_ORIGIN` | added by the sign-in library (Clerk); used only for account sign-in and device credentials |

No location, camera, microphone, contacts, SMS, storage or notification permission is
declared today (`POST_NOTIFICATIONS` will be added with push).

## 9. Encryption / export compliance

The app uses standard HTTPS/TLS only. Self-classify as "standard encryption" in Play
Console; no export licence exception is needed for that.

## 10. Play App Signing

Enrol with the existing upload key (`android/slnews-release.jks`, `CN=SLNews`), which
signed `build/dist/SLNews-1.0.0-1.aab`. Keep the keystore and `key.properties` out of
git; CI reads them from `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEY_PROPERTIES`.
