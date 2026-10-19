# SLNews mobile sync API — contract v1

Status: frozen for implementation. Owner: platform.
Backend: `SLNews` (Next.js route handlers + Prisma + Neon).
Consumer: `SLNews-App` (Flutter `SyncRepository`).
Related: [ROADMAP.md](ROADMAP.md) phases 1–4.

## Why this exists

The Flutter app keeps bookmarks, likes and follows in Hive, per device. Signing in
should make exactly those three collections follow the reader between devices and
survive a reinstall, using the same Clerk account as the web app.

The PWA's own `SavedArticle` references a PWA `Article` row; mobile items come from
the scraper API and RSS, and the PWA content model has no stable external id. So
mobile sync stores **its own user-scoped snapshot rows** keyed by the mobile item
id: enough metadata to render a saved list offline, no dependence on PWA content
rows, and no change to the existing web tables.

## Transport

| | |
| --- | --- |
| Base path | `/api/mobile/v1` |
| Auth | `Authorization: Bearer <clerk session JWT>`; cookie sessions also accepted for web-originated calls |
| Content type | `application/json; charset=utf-8` |
| Rate limit | 60 requests / 15 min per user, then `429` |
| Clock | All timestamps are ISO-8601 UTC with milliseconds (`2026-10-16T05:00:00.000Z`) |

## Item identity

Mobile item ids are stable strings produced by the app's ingest layer:

| Source | Shape | Example |
| --- | --- | --- |
| Scraper API | `slnews-api:<numeric id>` | `slnews-api:4821` |
| RSS/Atom | `rss:<fnv1a-64-hex>` | `rss:9f2c4a1b77e0d135` |
| Web article | `web:<cuid>` | `web:clx1a2b3c4d5e6f7g8h` |
| Follow target | kind prefix | `team:lal`, `league:spl`, `city:freetown`, `topic:politics`, `publisher:awoko` |

The API treats ids as opaque, unbounded strings (max 128 chars). It never resolves
them to content.

## GET /api/mobile/v1/sync — delta pull

Query:

| Param | Required | Notes |
| --- | --- | --- |
| `since` | no | ISO-8601; omit for full state. Returns rows with `updatedAt > since` |
| `limit` | no | 1–500, default 500, per collection |

`200`:

```json
{
  "serverTime": "2026-10-16T05:00:00.000Z",
  "hasMore": false,
  "bookmarks": [
    {
      "itemId": "slnews-api:4821",
      "title": "Leone Stars level with Guinea",
      "sourceUrl": "https://www.thesierraleonetelegraph.com/…",
      "imageUrl": null,
      "publisher": "The Sierra Leone Telegraph",
      "publishedAt": "2026-10-15T20:12:00.000Z",
      "savedAt": "2026-10-16T04:51:02.114Z",
      "updatedAt": "2026-10-16T04:51:02.114Z",
      "deleted": false
    }
  ],
  "reactions": [{ "itemId": "slnews-api:4821", "kind": "like", "updatedAt": "…", "deleted": false }],
  "follows": [
    { "targetId": "team:lal", "kind": "team", "label": "Los Angeles Lakers", "updatedAt": "…", "deleted": false }
  ]
}
```

Tombstones (`deleted: true`) are returned so a deletion on one device removes the
row on another. `hasMore` means at least one collection was truncated: re-issue
with `since` = the largest `updatedAt` received.

## POST /api/mobile/v1/sync — batched push

Request body: the same three collections, each an array of rows (tombstones
included). Any subset may be sent; each array defaults to empty.

```json
{
  "bookmarks": [ { "itemId": "…", "title": "…", "sourceUrl": "…", "imageUrl": null,
                   "publisher": "…", "publishedAt": "…", "savedAt": "…",
                   "updatedAt": "…", "deleted": false } ],
  "reactions": [ { "itemId": "…", "kind": "like", "updatedAt": "…", "deleted": false } ],
  "follows":   [ { "targetId": "…", "kind": "team", "label": "…", "updatedAt": "…", "deleted": false } ]
}
```

`200`:

```json
{
  "serverTime": "2026-10-16T05:00:00.000Z",
  "applied": { "bookmarks": 3, "reactions": 1, "follows": 0 },
  "rejected": [{ "collection": "bookmarks", "itemId": "slnews-api:4821", "reason": "stale" }],
  "state": { "bookmarks": [], "reactions": [], "follows": [] }
}
```

`state` carries the server's rows for everything the client touched, so a client
converges in one round trip (push → read back) instead of push-then-pull.

### Semantics

1. **Idempotent.** Re-sending the same batch makes no further change and returns
   `stale` for rows whose `updatedAt` is older than the stored value. Equal
   timestamps are idempotent-applied.
2. **Last-write-wins per row** on `updatedAt`, comparing ISO-8601 instants (not
   strings). The client's `updatedAt` is the moment the reader acted.
3. **Tombstones, never hard deletes.** `deleted: true` records `deletedAt` and the
   row keeps its `updatedAt`, so a stale device cannot resurrect it: a later
   non-deleted push is rejected as `stale`.
4. **Rejections are not errors.** They are reported per row and the rest of the
   batch still applies.
5. **Limits.** ≤ 500 rows per collection, ≤ 200 KB body. Exceeding them is
   `413`. Unknown fields are ignored; a row missing a required field is
   `400` for the whole request.

### Required fields per row

| Collection | Required |
| --- | --- |
| `bookmarks` | `itemId`, `title`, `updatedAt` (`savedAt` defaults to `updatedAt`) |
| `reactions` | `itemId`, `kind` (`like` today), `updatedAt` |
| `follows` | `targetId`, `kind` (`team`/`league`/`location`/`topic`/`publisher`), `updatedAt` |

## Status codes

| Code | Meaning |
| --- | --- |
| `200` | applied (inspect `rejected` for per-row conflicts) |
| `400` | malformed JSON, missing required field, bad timestamp/kind |
| `401` | missing, malformed, expired or unverifiable bearer token |
| `413` | payload over the row or byte cap |
| `429` | per-user rate limit exceeded (`Retry-After` set) |
| `500` | server fault (also reported to the PWA's error reporting) |

## Merge on first sign-in (client rule)

1. The reader signs in; the app pushes every local row with its local
   `updatedAt` (the moment the reader acted, not "now").
2. Concurrently it pulls the full server state.
3. Rows from both sides are unioned; per id the newer `updatedAt` wins — so a
   bookmark made on the phone before signing in survives, and one made on the web
   five minutes later wins over an older local copy.
4. Every local deletion becomes a tombstone push, so an offline delete is not
   undone by the pull.
5. After the first pass the app pushes deltas on change (debounced) and pulls on
   launch/foreground.

## Out of scope for v1

Content reconciliation with the web app's `SavedArticle` (needs a stable source
key on PWA `Article` — ROADMAP phase 5) and push notification registration
(phase 6). Both are additive later: `bookmarks` already carries `sourceUrl`, so a
future server-side join has the key it needs.
