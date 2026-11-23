# Identity, account scope and sync

## The rule

Signing in exists **only** to sync saved stories, likes and follows. It is not a
gate for reading, saving, liking, following or onboarding.

## Local state ownership

| State | Scope |
|---|---|
| Saved stories, likes, follows | Active account, or the separate `anonymous` namespace |
| Sync ledger | Active account |
| Onboarding completion | Device |
| Theme, text size, language, weather visibility, alert switches | Device |
| Digest enabled and quiet hours | Device; never sent to a server |
| Reading history, search recents, notification history | Device |

Account storage keys are suffixed with the Clerk user id. A signed-out reader
uses `anonymous`. Legacy global keys are migrated once to the active namespace
on first read. Signing out switches the active namespace to `anonymous`; the
previous account's data stays in its own namespace and is not visible or merged
into the next sign-in. Anonymous saves/follows are adopted once by the first
account that signs in, then the anonymous copy is cleared.

## Sync

`SlNewsApp` watches authentication at app level and calls
`SyncController.mergeOnSignIn()` once per account change, including a restored
session on launch. Signing out resets account-bound sync state and cancels
pending pushes/retries.

The sync payload remains exactly:

- `bookmarks`
- `reactions`
- `follows`

## Content

Read-only news and video are public:

- App public fallback: `/v1/public/news`, `/v1/public/videos` (deployed and
  verified on the Render API)
- `SlNewsApiConfig` is enabled by host alone; anonymous requests that receive
  401/403 retry the public routes.

The API exposes only the summary-only v1 payload publicly. Internal stats and
`/api/*` full-text routes remain authenticated and are not mounted under a
public path.
