# Architecture

SLNews follows a feature-first clean architecture with MVVM at the presentation
edge. Dependencies point **inwards**: widgets → view models/controllers →
repository contracts → data sources. Nothing in `core/domain` imports Flutter,
`dio`, Hive or Riverpod; the data layer never imports widgets.

```
┌─────────────────────────── presentation (features/*) ───────────────────────────┐
│  ConsumerWidget pages  →  view models / controllers (Riverpod)  →  shared widgets │
└───────────────────────────────────┬──────────────────────────────────────────────┘
                                    │ ref.watch(provider)
┌───────────────────────────────────▼──────────────────────────────────────────────┐
│ core/providers — the object graph: repositories, families, controllers, bootstrap│
└───────────────────────────────────┬──────────────────────────────────────────────┘
                                    │ implements
┌───────────────────────────────────▼──────────────────────────────────────────────┐
│ core/domain — entities (Article, GameScore, FollowTarget…) + repository contracts │
└───────────────────────────────────▲──────────────────────────────────────────────┘
                                    │ implemented by
┌───────────────────────────────────┴──────────────────────────────────────────────┐
│ core/data — FeedSource (RSS/REST/JSON) · Hive stores · repositories · seed assets │
└──────────────────────────────────────────────────────────────────────────────────┘
```

## Boot sequence

`main()` calls `AppBootstrap.create()`, which opens the Hive boxes, builds the
`ApiClient`, resolves the outlet registry into `FeedSource`s, constructs the
repositories and returns a list of Riverpod overrides. Every provider in
`app_providers.dart` is therefore **synchronous** — widgets never handle a
half-initialised app, and tests replace the whole graph with in-memory fakes.

If Hive fails to open, the bootstrap falls back to memory-only stores and the app
still runs (nothing survives a restart, and `AppBootstrap.isPersistent` reports
it).

## Offline-first reads

Every read resolves in this order and never throws to the UI:

```
in-memory → Hive cache (articles:<key>, synced:<key>) → bundled seed JSON → network
```

`OfflineFirstArticleRepository.refresh()` fans out to all sources concurrently
with a per-source timeout, swallows individual failures, merges, de-duplicates by
`Article.id` (newest wins), sorts by `publishedAt` descending and records the
sync time. `isOffline` stays true until an ingest actually yields stories, and
`OfflineBanner` surfaces that state without blocking reading.

`Article` ⇄ JSON is the single normalisation boundary: RSS items, REST payloads
and bundled seed entries all become `Article` once, in the data layer.

## State management (Riverpod 3)

- Infrastructure: `articleRepositoryProvider`, `sportsRepositoryProvider`,
  `followingRepositoryProvider`, `notificationRepositoryProvider`,
  `weatherRepositoryProvider`, `adRepositoryProvider`, `userStateProvider`.
- Derived data: `FutureProvider` families per category, location, article id,
  search query, team, league and ad placement. Providers are **not**
  auto-dispose, so switching tabs keeps content and scroll position.
- Reader state: `bookmarksControllerProvider`, `likesControllerProvider`,
  `followingControllerProvider`, `settingsControllerProvider`,
  `notificationsControllerProvider` (`AsyncNotifier`), plus a
  `refreshFeedsProvider` function used by pull-to-refresh.
- Controllers read/write through repository contracts only; persistence and
  network details never leak into a widget.

## Reader pipeline

`HtmlContent` parses the body with the `html` package and maps the small
block/inline subset news bodies use (`p`, `h2`–`h6`, `blockquote`, `ul`/`ol`,
`figure`/`img`, `pre`, `hr`, `strong`, `em`, `a`, `code`, `br`) onto design
system typography. Scripts, styles, iframes and event attributes are dropped;
unknown tags degrade to their text. This is why the reader needs no WebView and
renders identically offline — and why body rendering is unit-testable.

## Theming

`AppColors`, `AppTypography`, `AppSpacing`/`AppRadius`/`AppMotion` are the only
sources of colour, type, spacing and motion. `AppTheme.light()/dark()` composes
them into `ThemeData`, and `context.colors` / `context.typography` expose them to
widgets. The bundled Inter variable font is declared once as `SLNewsSans` and
selects weights through the `wght` axis, so the whole scale ships in one asset.

## Testing strategy

| Layer | Test |
| --- | --- |
| Utils (`TimeAgo`, `HtmlContent`) | pure unit tests with injected clocks |
| Models | JSON round-trip, derived getters, equality |
| Repositories | in-memory Hive fakes: fallback ordering, merge/dedupe, persistence |
| View models | pure Dart derivations (slicing, ordering, grouping) |
| Pages | widget tests with `ProviderScope` overrides, no network |
| Whole screens | golden renders under `test/golden/` |

No test performs network or file I/O beyond Hive's in-memory/temp stores.
