import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/local/preferences_store.dart';
import '../../../core/domain/models/article.dart';
import '../../../core/domain/models/video_moment.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/article_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/sl_network_image.dart';
import '../../../core/widgets/state_views.dart';

import 'package:slnews_mobile/core/utils/app_log.dart';

/// Search surface: query field, recent searches, stories and clips.
///
/// The repository already had `search()` and a provider; what was missing was
/// anywhere to type. Results group stories and videos, because a clip is a
/// legitimate answer to "what does SLNews have about X".
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  /// Persisted list of recent queries.
  static const String recentKey = 'search.recent';

  /// Queries kept; the list is newest-first and de-duplicated.
  static const int recentLimit = 8;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  List<String> _recent = const <String>[];
  PreferencesStore? _prefs;

  static const Duration _debounceDelay = Duration(milliseconds: 250);
  static const int _minQueryLength = 2;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _loadRecent() {
    try {
      _prefs = ref.read(preferencesStoreProvider);
    } on Object {
      _prefs = null;
    }
    final String? raw = _prefs?.string(SearchPage.recentKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        _recent = <String>[
          for (final Object? entry in decoded)
            if (entry is String && entry.trim().isNotEmpty) entry,
        ];
      }
    } catch (error) {
      AppLog.debug('SearchPage: recent searches unreadable ($error)');
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    final String query = value.trim();
    setState(() => _query = query);
    _remember(query);
  }

  void _applyRecent(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _focus.requestFocus();
    _submit(query);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
    _focus.requestFocus();
  }

  void _remember(String query) {
    if (query.length < _minQueryLength) return;
    final List<String> next = <String>[
      query,
      ..._recent.where(
        (String entry) => entry.toLowerCase() != query.toLowerCase(),
      ),
    ].take(SearchPage.recentLimit).toList(growable: false);
    setState(() => _recent = next);
    unawaited(_prefs?.putString(SearchPage.recentKey, jsonEncode(next)));
  }

  void _openArticle(Article article) {
    _remember(_query);
    context.push(AppRoutes.articleFor(article.id));
  }

  void _openVideo(VideoMoment video) {
    _remember(_query);
    context.push(AppRoutes.videoFor(video.id));
  }

  /// Videos whose title or outlet mentions the query.
  List<VideoMoment> _videoHits(String needle) {
    final List<VideoMoment> videos = ref.watch(videoMomentsProvider);
    final String lower = needle.toLowerCase();
    return videos
        .where(
          (VideoMoment video) =>
              video.title.toLowerCase().contains(lower) ||
              video.source.toLowerCase().contains(lower),
        )
        .take(3)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        leading: BackButton(color: context.colors.onSurface),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focus,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submit,
          style: context.typography.body,
          decoration: InputDecoration(
            hintText: 'Search SLNews',
            hintStyle: context.typography.body.copyWith(
              color: context.colors.onSurfaceFaint,
            ),
            border: InputBorder.none,
          ),
        ),
        actions: <Widget>[
          if (_query.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: _clear,
              icon: const Icon(Icons.close),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _query.length < _minQueryLength
          ? _Suggestions(
              recent: _recent,
              onSelect: _applyRecent,
              onClearRecent: () {
                setState(() => _recent = const <String>[]);
                unawaited(_prefs?.remove(SearchPage.recentKey));
              },
            )
          : _Results(
              query: _query,
              videos: _videoHits(_query),
              onOpenArticle: _openArticle,
              onOpenVideo: _openVideo,
            ),
    );
  }
}

/// Empty-field state: recent searches plus what search covers.
class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.recent,
    required this.onSelect,
    required this.onClearRecent,
  });

  final List<String> recent;
  final ValueChanged<String> onSelect;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    if (recent.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search,
        title: 'Search stories and videos',
        message: 'Find stories, videos and topics from across the country.',
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Recent searches',
                  style: context.typography.caption.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(onPressed: onClearRecent, child: const Text('Clear')),
            ],
          ),
        ),
        for (final String query in recent)
          ListTile(
            leading: Icon(Icons.history, color: context.colors.onSurfaceFaint),
            title: Text(query, style: context.typography.body),
            trailing: Icon(
              Icons.north_west,
              size: 18,
              color: context.colors.onSurfaceFaint,
            ),
            onTap: () => onSelect(query),
          ),
      ],
    );
  }
}

/// Query state: stories first, then clips, with honest empty and error states.
class _Results extends ConsumerWidget {
  const _Results({
    required this.query,
    required this.videos,
    required this.onOpenArticle,
    required this.onOpenVideo,
  });

  final String query;
  final List<VideoMoment> videos;
  final ValueChanged<Article> onOpenArticle;
  final ValueChanged<VideoMoment> onOpenVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Article>> articles = ref.watch(
      searchResultsProvider(query),
    );

    if (articles.hasError) {
      return ErrorStateView(
        message: "We couldn't search right now. Check your connection.",
        onRetry: () => ref.invalidate(searchResultsProvider(query)),
      );
    }
    if (!articles.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<Article> stories = articles.requireValue;
    if (stories.isEmpty && videos.isEmpty) {
      return EmptyStateView(
        icon: Icons.search_off,
        title: 'No results for "$query"',
        message: 'Try a shorter word, or check the spelling.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        if (stories.isNotEmpty) ...<Widget>[
          const SectionHeader(title: 'Stories'),
          for (final Article article in stories)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: ArticleTile(
                article: article,
                onTap: () => onOpenArticle(article),
                showPublisherMark: true,
              ),
            ),
        ],
        if (videos.isNotEmpty) ...<Widget>[
          const SectionHeader(title: 'Videos'),
          for (final VideoMoment video in videos)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              leading: ClipRRect(
                borderRadius: AppRadius.imageRadius,
                child: SizedBox(
                  width: 76,
                  height: 56,
                  // The outlet is already the subtitle; a labelled placeholder
                  // would print the name twice on a thumbnail-less row.
                  child: SlNetworkImage(url: video.thumbnailUrl),
                ),
              ),
              title: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.cardTitleSmall,
              ),
              subtitle: Text(
                video.source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.caption,
              ),
              trailing: const Icon(Icons.play_circle_outline),
              onTap: () => onOpenVideo(video),
            ),
        ],
      ],
    );
  }
}
