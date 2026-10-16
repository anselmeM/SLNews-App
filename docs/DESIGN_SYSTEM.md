# Design system

The visual language mirrors the Samsung News reference screens: a soft neutral
canvas, pure white cards with 16 pt radii and no shadows, near-black type with
tight tracking on headlines, and a single saturated blue accent.

All tokens live in `lib/core/theme/` and are reached from widgets through
`context.colors`, `context.typography` (both from `app_typography.dart`) and the
`AppSpacing` / `AppRadius` / `AppMotion` constants. Widgets never hard-code a
colour, font size or gap.

## Colour

| Token | Light | Dark | Used for |
| --- | --- | --- | --- |
| `canvas` | `#F1F1F1` | `#000000` | page background |
| `surface` | `#FFFFFF` | `#171717` | cards, sheets, nav bar |
| `surfaceMuted` | `#F4F4F4` | `#232323` | pills, thumbnails, score tiles |
| `surfaceInverse` | `#111111` | `#FFFFFF` | selected category pill, filled buttons |
| `onSurface` | `#111111` | `#F5F5F5` | primary text |
| `onSurfaceVariant` | `#6B6B6B` | `#A6A6A6` | timestamps, secondary text |
| `onSurfaceFaint` | `#9A9A9A` | `#7A7A7A` | captions, ad disclosure |
| `divider` | `#E6E6E6` | `#2C2C2C` | hairlines inside card groups |
| `primary` | `#0381FE` | `#4C9CFF` | active like, links, unread badge |
| `live` | `#E03B3B` | `#FF6B6B` | `BREAKING` / `LIVE` markers |
| `accentGradient*` | `#2E9BF5`→`#0B6FD1` | darker | ad panel fill |

`AppColors` are plain immutable value objects (not a `ThemeExtension`) so light
and dark palettes are `const` and testable without a `BuildContext`.

## Typography

One bundled variable font — Inter, family `SLNewsSans` — with weights selected
through the `wght` axis (`fontVariations`), so a single 876 KB asset covers the
whole scale. `Roboto`/`Helvetica Neue`/`Arial` are the fallbacks.

| Token | Size / weight | Role |
| --- | --- | --- |
| `screenTitle` | 34 / 700, −0.8 | "Top stories", "Sports" page titles |
| `sectionTitle` | 24 / 700, −0.5 | section headers with a `›` |
| `groupTitle` | 19 / 700 | card-group headers ("Sports", "Locations") |
| `cardTitle` | 19 / 700 | feed card headlines |
| `cardTitleSmall` | 17 / 700 | grid card headlines |
| `heroTitle` | 28 / 700, white | headline over a hero image |
| `articleTitle` | 30 / 700, −0.7 | reader headline |
| `lead` | 19 / 500 | standfirst |
| `body` | 17 / 400, 1.62 | article body |
| `meta` | 13.5 / 500 | publisher, age, "Powered by" |
| `caption` | 13 / 400 | image caption and credit |
| `publisherMark` | 13 / 700, +0.4 | wordmark when no logo |
| `chip` | 15 / 600 | category pills, follow chips |
| `overline` | 11 / 700, +0.8 | `AD`, `BREAKING`, disclosure |
| `score` | 16 / 700, tabular | scoreboard numerals |
| `navLabel` | 12 / 600 | bottom navigation labels |

## Spacing, radius, motion

4 pt grid: `2 / 4 / 8 / 12 / 16 / 20 / 24 / 32`. Page gutter 16, card padding 16,
gap between cards 12. Radii: `8` (tags) `12` (images) `16` (cards) `22` (sheets)
`999` (pills). Motion: 140 ms for state flips, 240 ms for image fades, always
`easeOutCubic` — nothing bounces.

## Component vocabulary

`lib/core/widgets/` is the shared vocabulary every feature composes:

| Widget | Purpose |
| --- | --- |
| `SlPageScaffold` / `SlPageTitle` | page chrome: compact brand row *or* large title, pinned bottom bar, pull-to-refresh |
| `ArticleHeroCard` | 420 pt graded hero with overlaid headline, breaking tag, meta row, like + kebab |
| `ArticleTile` | text-left/thumbnail-right feed card |
| `ArticleGridTile` | two-column grid card for sub-category stories |
| `PublisherMark` | logo when available, uppercase wordmark otherwise |
| `SlNetworkImage` | cached image with a layout-stable, labelled placeholder |
| `CategoryPill` / `CategoryPillStrip` | horizontal filter pills (inverted when selected) |
| `FollowChip` | outlined Follow ⇄ muted Following pill |
| `LikeButton` | outlined thumb ⇄ filled blue thumb with a short pop |
| `OverflowMenuButton` | kebab menu with the `ArticleAction` set |
| `AdCard` | locally painted, clearly labelled native-style ad unit |
| `SkeletonBox` / `ArticleTileSkeleton` / `HeroCardSkeleton` | shimmering load states |
| `ErrorStateView` / `EmptyStateView` / `OfflineBanner` | non-blocking failure and empty states |
| `HtmlContent` | article body renderer onto the type scale |

## Rules

1. Cards are white `surface` at 16 pt radius with **no shadow**; only the
   reader's floating action bar and the ad's offer card are elevated.
2. Text hierarchy comes from the tokens above — do not introduce new sizes.
3. Every image sits in a fixed-size box so loading never shifts layout.
4. Tap targets are ≥ 44 pt; icon-only controls carry `Semantics`/`Tooltip`.
5. Dark mode is not an afterthought: every token has a dark value, and the
   `canvas` goes to pure black as in the reference app.
6. Long headlines ellipsize; nothing is clipped or scaled down.
