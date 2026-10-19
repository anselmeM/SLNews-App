# SLNews Mobile — implementation contract

This document is the **frozen interface** between the shared core (owned by the
Lead) and the feature modules (owned by feature agents). Read it fully before
writing code. If something here is wrong or impossible, report it — do not
change shared files.

## 0. Project facts

| Item | Value |
| --- | --- |
| Project root | `C:\Users\amotc\Documents\GitHub\SLNews-App` |
| Flutter SDK (not on PATH) | `C:\Users\amotc\flutter\flutter\bin\flutter.bat` |
| Dart | 3.13.5 (Flutter 3.47.7, stable) |
| State management | Riverpod **3.4.3** (`flutter_riverpod`) |
| Routing | `go_router` 18.1.0 |
| Storage | Hive (`hive`, `hive_flutter`) |
| Networking | `dio` (inside the data layer only) |
| Fonts | bundled Inter variable font, family `SLNewsSans` |
| Lints | `flutter_lints` + `unused_import`/`unused_local_variable`/`unawaited_futures` are **errors** |

PowerShell form for every command:

```powershell
& 'C:\Users\amotc\flutter\flutter\bin\flutter.bat' analyze lib/features/<yours>
& 'C:\Users\amotc\flutter\flutter\bin\flutter.bat' test test/features/<yours>
```

Do **not** run `dart format .` or `flutter analyze` (unscoped) while other agents
are mid-write; scope formatting to your own files.

## 1. Ownership map — never edit outside your scope

| Path | Owner |
| --- | --- |
| `lib/core/domain/**` (models + repository interfaces) | Lead (frozen) |
| `lib/core/theme/**` | Lead (frozen) |
| `lib/core/providers/**` | Lead (frozen) |
| `lib/core/widgets/**` | Lead (frozen) |
| `lib/core/utils/**` | Lead (frozen) |
| `lib/core/routing/**`, `lib/core/shell/**`, `lib/app.dart`, `lib/main.dart` | Lead (frozen) |
| `lib/core/data/**`, `assets/seed/**` | Data agent (in progress) |
| `lib/features/feed/**` | Feed agent |
| `lib/features/news/**` | News agent |
| `lib/features/sports/**` | Sports agent |
| `lib/features/following/**` | Following agent |
| `lib/features/article/**` | Lead |
| `lib/features/bookmarks/**` | Feed agent |
| `pubspec.yaml`, `android/**`, `ios/**`, `analysis_options.yaml` | Lead (frozen) |

Feature modules may create **any** file inside their own directory
(`presentation/`, `presentation/widgets/`, `presentation/viewmodels/`).
They must not create files anywhere else.

## 2. Design tokens

Import `package:slnews_mobile/core/theme/app_typography.dart` to get both the
`context.colors` and `context.typography` extensions (it re-exports nothing else
— import `app_spacing.dart` for spacing).

### `context.colors` (`AppColors`)

`canvas`, `surface`, `surfaceMuted`, `surfaceInverse`, `onSurface`,
`onSurfaceVariant`, `onSurfaceFaint`, `onSurfaceInverse`, `divider`, `primary`,
`onPrimary`, `accentGradientStart`, `accentGradientEnd`, `skeleton`,
`skeletonHighlight`, `overlayScrim`, `live`.

Light: `canvas #F1F1F1`, `surface #FFFFFF`, `onSurface #111111`,
`onSurfaceVariant #6B6B6B`, `primary #0381FE`, `live #E03B3B`.
Dark: `canvas #000000`, `surface #171717`, `onSurface #F5F5F5`,
`onSurfaceVariant #A6A6A6`, `primary #4C9CFF`.

### `context.typography` (`AppTypography`)

`screenTitle` 34/700 · `sectionTitle` 24/700 · `groupTitle` 19/700 ·
`cardTitle` 19/700 · `cardTitleSmall` 17/700 · `heroTitle` 28/700 white ·
`articleTitle` 30/700 · `lead` 19/500 · `body` 17/400 · `caption` 13/400 ·
`meta` 13.5/500 · `publisherMark` 13/700 · `chip` 15/600 · `navLabel` 12/600 ·
`button` 15/600 · `score` 16/700 tabular · `overline` 11/700.

Never hard-code a `TextStyle`; compose from these (`context.typography.body.copyWith(...)`).
Never hard-code a colour; use `context.colors.*` (white-on-image overlays are the
only allowed exceptions).

### Spacing / radius / motion (`app_spacing.dart`)

`AppSpacing.xxs/xs/sm/md/lg/xl/xxl/xxxl` = 2/4/8/12/16/20/24/32.
`AppSpacing.page` (16 horizontal gutter), `AppSpacing.card` (16 all),
`AppSpacing.row` (16/14).
`AppRadius.sm/md/lg/xl/pill`, `AppRadius.cardRadius` (16), `AppRadius.imageRadius` (12),
`AppRadius.pillRadius`.
`AppMotion.fast` 140 ms, `AppMotion.medium` 240 ms, `AppMotion.standard` easeOutCubic.

## 3. Domain models (frozen, in `lib/core/domain/models/`)

- `Article` — `id, title, summary, bodyHtml, author, imageUrl, imageCaption, imageCredit,
  sourceUrl, publisher, publishedAt, categoryId, tags, isBreaking, isLive, readingMinutes`;
  getters `relativeAge`, `estimatedReadingMinutes`; `copyWith`, `toJson`, `fromJson`.
- `Publisher` — `id, name, wordmark, logoUrl, websiteUrl, country, isWire`; getter `mark`.
- `NewsCategory` — `id, label, icon, isDefault`; catalogue `NewsCategories.all` / `NewsCategories.byId(id)`.
- `GameScore` / `Team` / `ScoreboardSnapshot` / `TeamStanding` / `GameStatus` (`sports_models.dart`).
- `FollowTarget` / `FollowKind` / `FollowingSnapshot` / `NewsLocation` / `SlLocations` (`follow_models.dart`).
- `NotificationItem` / `NotificationKind` (`notification_item.dart`).
- `WeatherSnapshot` (`weather_snapshot.dart`), `AdUnit` (`ad_unit.dart`).
- `AppSettings` / `AppThemeMode` (`app_settings.dart`).
- `TimeAgo` + `DateTimeLabels` extension (`lib/core/utils/time_ago.dart`):
  `relativeAge`, `relativeLabel`, `shortRelativeLabel`, `absoluteLabel`,
  `shortDateLabel`, `clockLabel`.

## 4. Providers (frozen, `lib/core/providers/`)

`app_providers.dart`:

| Provider | Type |
| --- | --- |
| `topStoriesProvider` | `FutureProvider<List<Article>>` |
| `categoryFeedProvider(categoryId)` | `FutureProviderFamily<List<Article>, String>` |
| `locationFeedProvider(locationId)` | `FutureProviderFamily<List<Article>, String>` |
| `articleProvider(id)` | `FutureProviderFamily<Article?, String>` |
| `searchResultsProvider(query)` | `FutureProviderFamily<List<Article>, String>` |
| `scoreboardProvider` | `FutureProvider<ScoreboardSnapshot>` |
| `teamGamesProvider(teamId)` | `FutureProviderFamily<List<GameScore>, String>` |
| `standingsProvider(leagueId)` | `FutureProviderFamily<List<TeamStanding>, String>` |
| `adUnitsProvider(placement)` | `FutureProviderFamily<List<AdUnit>, String>` |
| `activeWeatherProvider` | `FutureProvider<WeatherSnapshot>` |
| `selectedCategoryProvider` | `NotifierProvider<SelectedCategoryController, String>` (`.select(id)`) |
| `articleRepositoryProvider`, `sportsRepositoryProvider`, `followingRepositoryProvider`, `userStateProvider`, `notificationRepositoryProvider`, `adRepositoryProvider` | repository instances |

`controllers.dart`:

| Provider | Type / API |
| --- | --- |
| `settingsControllerProvider` | `NotifierProvider<SettingsController, AppSettings>`; methods `setThemeMode`, `setTextScale`, `cycleTextScale`, `setActiveLocation`, `setBreakingNewsAlertsEnabled` |
| `bookmarksControllerProvider` | `NotifierProvider<BookmarksController, Set<String>>`; `isBookmarked(id)`, `toggle(id)` |
| `likesControllerProvider` | `NotifierProvider<LikesController, Set<String>>`; `isLiked(id)`, `toggle(id)` |
| `followingControllerProvider` | `NotifierProvider<FollowingController, FollowingSnapshot>`; `toggle(target)`, `follow(target)`, `unfollow(id)` |
| `notificationsControllerProvider` | `AsyncNotifierProvider<NotificationsController, List<NotificationItem>>`; `markRead(id)`, `markAllRead()`, `reload()`, `unreadCount` |
| `refreshFeedsProvider` | `Provider<Future<void> Function()>` — pull-to-refresh |

Consumption pattern (Riverpod 3, no code generation):

```dart
class ForYouPage extends ConsumerWidget {
  const ForYouPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Article>> stories = ref.watch(topStoriesProvider);
    final bool isLiked = ref.watch(likesControllerProvider).contains(article.id);
    return stories.when(
      data: (List<Article> data) => ...,
      loading: () => const ArticleTileSkeleton(),
      error: (Object error, StackTrace stack) => ErrorStateView(onRetry: () => ref.invalidate(topStoriesProvider)),
    );
  }
}
```

### Riverpod 3 rules

- Providers are **not** auto-dispose by default (`isAutoDispose = false`); do not
  add `.autoDispose`.
- `Ref` is **not** generic: write `(Ref ref, String arg) => ...`, never `Ref<Foo>`.
- Do **not** use `StateProvider`, `StateNotifierProvider` or `ChangeNotifierProvider`
  (legacy in v3). Use the controllers listed above or a local
  `NotifierProvider<MyNotifier, MyState>(MyNotifier.new)`.
- Mutating a `Set`/`List` in place does not notify: assign a new instance
  (`state = <String>{...state, id}`).
- `ref.invalidate(someFamilyProvider)` invalidates every instance of a family
  (used by pull-to-refresh).
- Never call `ref.read` inside `build`; use `ref.watch` for reactive reads.

## 5. Shared widgets (frozen, `lib/core/widgets/`)

```dart
// Page chrome. brandMark != null → compact "SLNews ⋮" row, and you render the
// page title in the content with SlPageTitle (For You, News).
SlPageScaffold({
  required String title,
  String? brandMark,
  List<Widget> actions = const <Widget>[],
  List<Widget> slivers = const <Widget>[],
  Widget? body,
  PreferredSizeWidget? bottom,          // e.g. pinned CategoryPillStrip
  bool showOverflow = true,
  ValueChanged<ArticleAction>? onOverflowSelected,
  Future<void> Function()? onRefresh,   // wraps content in RefreshIndicator
  Widget? floatingActionButton,
  bool showTitleInAppBar = true,
});

SlPageTitle({required String title, VoidCallback? onTap, Widget? trailing});

SectionHeader({
  required String title,
  VoidCallback? onTap,                  // draws the trailing "›"
  Widget? trailing,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 20, 16, 12),
  bool compact = false,
});

ArticleHeroCard({                      // full-bleed graded hero with overlaid headline
  required Article article,
  VoidCallback? onTap, VoidCallback? onLike,
  ValueChanged<ArticleAction>? onMore,
  bool isLiked = false, double height = 420,
  bool showPublisherMark = true, bool showSummary = false,
  EdgeInsetsGeometry margin = EdgeInsets.zero,
});

ArticleTile({                          // text + right thumbnail card
  required Article article,
  VoidCallback? onTap, VoidCallback? onLike,
  ValueChanged<ArticleAction>? onMore,
  bool isLiked = false,
  double thumbnailWidth = 122, double thumbnailHeight = 120,
  bool showPublisherMark = true, bool showSummary = false, bool showThumbnail = true,
});

ArticleGridTile({                      // 2-column grid card, image on top
  required Article article,
  VoidCallback? onTap, ValueChanged<ArticleAction>? onMore,
  double imageAspectRatio = 16 / 10, int maxTitleLines = 3,
});

PublisherMark({required Publisher publisher, double logoHeight = 18, Color? color, double maxWidth = 160});
SlNetworkImage({String? url, double? width, double? height, BoxFit fit = BoxFit.cover,
                BorderRadius? borderRadius, String? placeholderLabel, Alignment alignment = Alignment.center});
LikeButton({required bool isLiked, VoidCallback? onPressed, double size = 20, String? semanticLabel});
OverflowMenuButton({ValueChanged<ArticleAction>? onSelected, List<ArticleAction> items = const <ArticleAction>[...],
                    double size = 20, Color? color, String tooltip = 'More options'});
FollowChip({required bool isFollowing, required VoidCallback? onPressed,
            String followLabel = 'Follow', String followingLabel = 'Following', bool dense = false});
CategoryPill({required String label, required bool selected, VoidCallback? onTap, IconData? icon});
CategoryPillStrip({required List<NewsCategory> categories, required String selectedId,
                   required ValueChanged<NewsCategory> onSelected,
                   EdgeInsetsGeometry padding = ..., bool showIcons = false, ScrollController? controller});
AdCard({required AdUnit unit, VoidCallback? onCtaPressed, ValueChanged<AdUnit>? onOpened});
SkeletonBox({double? width, double? height, BorderRadius borderRadius, BoxShape shape});
ArticleTileSkeleton(); HeroCardSkeleton({double height = 420});
ErrorStateView({String message, VoidCallback? onRetry, IconData icon});
EmptyStateView({required String title, String? message, String? actionLabel, VoidCallback? onAction, IconData icon});
OfflineBanner({required bool isOffline, String message, DateTime? lastSyncedAt});
AppGlyphs.category(key) / AppGlyphs.weather(key) / AppGlyphs.follow(FollowKind) /
AppGlyphs.notification(key) / AppGlyphs.initials(label);
HtmlContent({required String html, double spacing = 16});   // article bodies
```

`ArticleAction` enum: `bookmark, removeBookmark, share, openInBrowser,
followPublisher, hide, report` — each has `.label` and `.icon`.

## 6. Visual language (must match the reference screens)

- Page background is `canvas` (soft grey / black), every card is a **white
  `surface` with 16pt radius and no shadow**. Cards are separated by 12pt gaps.
- Feed cards: outlet mark (or wordmark) on top, bold 19pt headline, then a meta
  row with the age on the left and like + kebab on the right.
- Hero cards: 420pt tall image, dark bottom-up scrim, 28pt white headline,
  then outlet wordmark · age, then like + kebab. Add a red `BREAKING`/`LIVE`
  tag when `article.isBreaking` / `article.isLive` (already handled by the widget).
- Section headers are 24pt bold and tappable, with a trailing `›`.
- Category pills: selected = near-black pill with white 15/600 label;
  unselected = white pill, dark label.
- Tap targets ≥ 44pt; nothing below 12pt type; all list content scrolls
  (`BouncingScrollPhysics` not required — default platform physics).
- Images: always via `SlNetworkImage` (never `Image.network`), always with a
  fixed width/height or `AspectRatio` so loading never shifts layout.
- Accessibility: wrap icon-only controls in `Semantics`/`Tooltip` as the shared
  widgets do; keep text contrast as provided by the tokens.

## 7. Deliverable expectations per feature

- Page class with the **exact constructor** listed below, implemented with
  `ConsumerWidget` (add a private `ConsumerStatefulWidget` only when local
  widget state is unavoidable, e.g. a `TabController` or animation).
- Handle all three `AsyncValue` states and the empty case; never show a raw
  exception string.
- Any destructive/remote action shows a `SnackBar` confirmation via
  `ScaffoldMessenger`.
- Widget tests under `test/features/<yours>/` that pump the page with
  `ProviderScope(overrides: [...])` using the in-memory fakes from
  `test/support/fakes.dart` (created by the Lead; if it is not there yet,
  create **only** the fakes your tests need inside your own test directory).
- Line-level doc comments on public classes and non-obvious decisions.

Frozen page constructors:

```dart
class ForYouPage extends ConsumerWidget { const ForYouPage({super.key}); }
class NewsPage extends ConsumerWidget { const NewsPage({super.key}); }
class SportsPage extends ConsumerWidget { const SportsPage({super.key}); }
class FollowingPage extends ConsumerWidget { const FollowingPage({super.key}); }
class NotificationHistoryPage extends ConsumerWidget { const NotificationHistoryPage({super.key}); }
class SavedStoriesPage extends ConsumerWidget { const SavedStoriesPage({super.key}); }
```

Routes already wired by the Lead in `app_router.dart` — do not edit the router:

| Route | Page | Notes |
| --- | --- | --- |
| `/for_you` | `ForYouPage` | tab 1 |
| `/news` | `NewsPage` | tab 2 |
| `/sports` | `SportsPage` | tab 3 |
| `/following` | `FollowingPage` | tab 4 |
| `/following/notifications` | `NotificationHistoryPage` | nested in tab 4, keeps the nav bar |
| `/article/:id` | `ArticlePage` | pushed above the shell (Lead-owned) |
| `/saved` | `SavedStoriesPage` | pushed above the shell |

Navigate with `context.go(AppRoutes.x)` / `context.push(AppRoutes.articleFor(id))`
(`package:slnews_mobile/core/routing/app_routes.dart`).
