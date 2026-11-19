# Release and rollback runbook

The app ships as a signed AAB to Google Play, backed by two services that deploy
independently: the Next.js web app on Vercel and the scraper on Render. This is
the procedure for shipping a build and for getting back to a known-good state
when one of the three moves badly.

## 1. What ships where

| Component | Artefact | Where it runs | Deploy trigger |
|---|---|---|---|
| Android app | `app-release.aab` (signed) | Google Play | manual upload / CI artefact |
| Web | Next.js build | Vercel | push to `master` |
| Scraper + API | Node service | Render | push to `master` |
| Database | additive SQL (`docs/mobile-sync-migration.sql`) | managed Postgres | `vercel-build` script |

The app is the only component users install, so it is the slowest to roll back.
Treat its release as the last step, after the services are verified.

## 2. Pre-release checklist

1. `pubspec.yaml` versionCode is **higher than the last uploaded build**.
2. CI green on `master`: APK + AAB jobs, coverage gate, new-file gate, secret scan.
3. Web and scraper deployed from the same commit range and healthy:
   - `https://sl-news.vercel.app/api/health`
   - `https://slnewsapiscapper.onrender.com/api/health`
4. Crash reporting verified (section 3).
5. Install the release APK on a physical device and walk: For You → article →
   save → follow a topic → Sports → Markets. Check the account row and alerts.
6. Store listing, data-safety and content-rating answers still match behaviour.

## 3. Verifying crash reporting before a release

The Settings verification rows are hidden in production builds unless the build
opts in, so a store-pipeline check is a separate build:

```bash
flutter build apk --release \
  --dart-define=SENTRY_DSN="$SENTRY_DSN" \
  --dart-define=SENTRY_ENV=production \
  --dart-define=SENTRY_VERIFY=true
```

Install it, open **Settings → About → Send test exception**, then confirm the
event in the Sentry project for the release version. Do not ship the
`SENTRY_VERIFY` build; rebuild without that define.

If no event arrives, check in this order: the DSN is present in the APK
(`strings libapp.so | grep -i sentry`), the device has network, and the Sentry
project's inbound filters are not dropping the release.

## 4. Shipping to Play

1. Upload the AAB to the **internal testing** track first.
2. Complete the pre-launch report; a crash there blocks promotion.
3. Promote to **closed testing**; keep the tester list current.
4. Promote to production with a **staged rollout** (10 % → 50 % → 100 %), holding
   each step for at least a day and watching Sentry crash-free sessions.
5. Keep the previous AAB and its mapping file until the rollout completes.

## 5. Rollback

### 5.1 Android app

Google Play does not allow installing a lower versionCode, so "rollback" means
one of:

- **Halt the staged rollout** (Play Console → Release → Halt rollout). Users who
  have not updated stay on the previous version; users who did keep the new one.
- **Ship a hotfix** with a versionCode higher than the bad build, reverting the
  offending change. This is the only way to move everyone back.

Before halting, capture: the bad versionCode, the Sentry release tag, the crash
signature, and the first-seen timestamp.

### 5.2 Web (Vercel)

1. Find the last known-good deployment in the Vercel dashboard (Deployments).
2. **Promote to Production** on that deployment, or run `vercel rollback`.
3. Verify `/api/health`, sign-in and one article page.
4. The rollback is instant for new requests; cached pages may lag by the ISR
   window.

### 5.3 Scraper (Render)

1. Render dashboard → service → **Deploys** → pick the previous successful
   deploy → **Redeploy**.
2. Verify `GET /api/health` returns `{"status":"ok"}`.
3. Check the next cron run logs for `[cron] follow digest` and ingestion counts.

### 5.4 Database

Schema changes are additive and idempotent (`ALTER TABLE ... ADD COLUMN IF NOT
EXISTS`, `CREATE TABLE IF NOT EXISTS`). There is no down-migration, by design:
revert the application code and leave the columns in place. A column that is
unused costs nothing; a dropped column loses reader data.

If a write path is producing bad data, stop it at the source (halt the cron or
redeploy the previous web build) rather than mutating rows under a live app.

### 5.5 Notifications

Pushes cannot be recalled. If a bad digest or alert is sent:

1. Stop the source: disable the cron (`vercel.json` schedule) or redeploy the
   previous web build.
2. Publish a correction through the same topic if the error is material.
3. Record which topic and how many devices the FCM response reported.

## 6. Post-incident

- Add a regression test at the layer that failed (unit for logic, widget for UI,
  a fresh `test/security` case for a manifest/URL regression).
- Note the Sentry release and the fix versionCode in the issue.
- If the rollback path itself was unclear, update this document in the same PR as
  the fix.
