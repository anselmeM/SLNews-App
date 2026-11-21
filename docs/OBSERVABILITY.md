# Observability — crash and error reporting

Status: **live.** Project `firstmiledevs/slnews-mobile` (id `4512278655139840`); DSN stored
as the `SENTRY_DSN` GitHub secret and passed by both CI workflows; a direct event POST
returned HTTP 200, so ingest is verified. Builds without the secret still run with
reporting disabled by design. The wizard's release-upload token lives in the gitignored
`sentry.properties` and is unused by the app.

The backend is already instrumented: `SLNews` uses `@sentry/nextjs`
(`sentry.server.config.ts`, `sentry.edge.config.ts`, `tracesSampleRate: 0.1`, enabled
only when `SENTRY_DSN` is set in Vercel).

---

## What the app reports (once enabled)

| Sent fronted data | Not sent |
| --- | --- |
| Dart/Flutter uncaught exceptions with stack traces | IP address (`sendDefaultPii: false`; also disable IP storage in the project — see below) |
| Native Android crashes (Sentry Android SDK, auto-init) | User email, name or account id (no `Sentry.setUser`) |
| App version (`slnews-mobile@1.0.0+2`), environment | Screenshots, view hierarchy, request bodies |
| Breadcrumbs (navigation, lifecycle) | Reading, search or saved-story content |
| A bootstrap failure ticket if the app cannot start | Advertising identifiers |

Traces are sampled at **5 %** — this is crash reporting, not full APM. Errors are
captured at **100 %**.

## Configuration (all build-time)

| Define | Required | Meaning |
| --- | --- | --- |
| `SENTRY_DSN` | for reporting | project client key; empty disables everything |
| `SENTRY_ENV` | no | `production` (default in release), `staging`, `development` |
| `SLNEWS_RELEASE` | no | defaults to `slnews-mobile@<pubspec version>` |

Sources of truth:

- **Local builds**: `$env:SENTRY_DSN` is picked up by `scripts/build_apk.ps1`; the AAB
  script reads it directly and stamps the release.
- **CI**: repository secret `SENTRY_DSN`, passed to the build as a dart-define by
  the `bundle` job in `build-apk.yml` and the protected-branch APK step. A build without the secret logs
  a warning and ships without reporting — it does not fail.

## Creating the Sentry projects (org `firstmiledevs`)

**One project is enough** for Android and iOS: Sentry accepts both from a single Flutter
project and separates them by platform. Recommended:

| Project slug | Platform | Used by |
| --- | --- | --- |
| `slnews-flutter` | Flutter/Dart | Android now, iOS later |
| `slnews` (existing) | Next.js | website + API (already instrumented) |

The project exists (created by the Flutter wizard) and its DSN is stored as the
`SENTRY_DSN` GitHub secret. Project toggles that still need a human:
**Prevent Storing of IP Addresses** and a daily **rate limit** in Inbound Filters.
3. **Settings → Security & Privacy**: turn on **Prevent Storing of IP Addresses** (keeps
   the privacy policy's "no IP" claim true).
4. **Settings → Inbound Filters**: enable "Filter out errors known to be caused by browser
   extensions" (harmless) and set a **rate limit** (e.g. 1 000 events/day) so a loop cannot
   exhaust quota.
5. **Settings → Release details**: no upload step needed — builds are not obfuscated, so
   Dart stack traces are readable. Native symbolication comes from Play/Android automatic
   mapping; add `sentry-cli` symbol upload later only if obfuscation is enabled.

The wizard's own token is scoped for release uploads only (the API answers 403 for
project metadata); the DSN was copied from the project UI and stored as a secret, never in
source.

## Verifying a report

1. Build with the DSN: `$env:SENTRY_DSN='…'; powershell -File scripts/build_apk.ps1`.
2. In a **debug** build — or a release build compiled with
   `--dart-define=SENTRY_VERIFY=true` — Settings → About shows two actions (only when
   reporting is enabled): **Send test event** posts a message, and **Send test exception** throws and
   captures `StateError('This is test exception')` — the same check Sentry's Flutter guide
   recommends. Both appear in the project's Issues within seconds.
3. Or use the real path: the bootstrap error screen calls `reportError`, and uncaught Dart
   errors go through Sentry's handlers automatically.

## Before shipping reporting to production

- [x] Project created; DSN in CI secret and local env.
- [x] **Privacy policy updated** (`SLNews` → `/privacy` PR `chore/sentry-diagnostics`):
      Sentry in the provider list, crash-diagnostics paragraph, 90-day retention.
- [x] **Data safety updated** (`store/play/DATA-SAFETY.md`): Diagnostics → Crash logs
      (and sampled performance) collected, not shared, encrypted in transit, deletion
      available.
- [ ] "Prevent Storing of IP Addresses" enabled for the project (Sentry UI).
- [ ] Daily rate limit set in Inbound Filters (Sentry UI).
- [ ] Verify from a device with the verification APK (Settings → About).
- [x] Checklist B6 closed.

## Deliberately not collected

No user identity is attached (`Sentry.setUser` is never called), no PII, no screenshots.
If support ever needs to correlate a report with an account, do it through the
`user_${hash}` pattern rather than email addresses, and disclose it.
