# Production audit — fix task list

Source: the 2026-11-22 production audit of `SLNews-App` and `SLNews-Web`.
Status: `[x]` done · `[~]` implemented, hardware/rollout step outstanding

| # | Task | Repo | Status | Verification |
|---|---|---|---|---|
| 1 | Pin the validated image-proxy address to close DNS-rebinding SSRF | Web | [x] | `safe-image-fetch.ts` uses an undici dispatcher with a fixed lookup; tests cover the returned pinned address |
| 2 | Enforce sponsorship lifetime/daily caps atomically | Web | [x] | Postgres advisory transaction lock plus in-transaction recheck; cap tests added |
| 3 | Do not let expired/invalid events poison the offline outbox | App | [x] | Permanent 4xx events are removed; later events continue flushing; test added |
| 4 | Clamp client sync timestamps to server time | Web | [x] | Future `updatedAt` is clamped to now + 5 minutes; tests added |
| 5 | Replace production `db push` with a real migration baseline | Web | [x] | Migration baseline applied; legacy index migration applied; `migrate status` clean |
| 6 | Guard notification-tap listeners against duplicate registration | App | [x] | `onMessageOpenedApp` and initial-message handling guarded |
| 7 | Report sponsorship event transaction failures | Web | [x] | Catch calls `reportError`; test asserts it |
| 8 | Time-box token-less legacy events | Web | [x] | Default cutoff 2027-01-31 plus `SPONSORSHIP_LEGACY_EVENTS_UNTIL`; test added |
| 9 | Authenticate/rate-limit before parsing sync bodies | Web | [x] | POST resolves the caller first; 413 test updated |
| 10 | Attribute Sentry crashes to the real build | App | [x] | CI derives `SLNEWS_RELEASE` from `pubspec.yaml`; default changed to `@dev` |
| 11 | Add a native device smoke-test harness | App | [~] | `integration_test/app_smoke_test.dart` added; needs an Android device/emulator run |
| 12 | Harden client-IP extraction | Web | [x] | Prefer Vercel's `x-vercel-forwarded-for`; trust boundary documented |
| 13 | Constrain raw-SQL sync identifiers | Web | [x] | Table/key/column shape allow-list added; engine tests pass |

## Operational follow-up

After the updated app replaces the old installs, set
`SPONSORSHIP_ALLOW_LEGACY_EVENTS=false` in Vercel. The built-in cutoff closes
the bridge on 2027-01-31 even if nobody changes the env var.

Run the device smoke test before Play release:

```powershell
flutter test integration_test -d <android-device-id>
```
