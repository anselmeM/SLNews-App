import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/models/follow_models.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_glyphs.dart';
import '../../../core/widgets/state_views.dart';
import 'widgets/catalogue_list.dart';
import 'widgets/catalogue_page_scaffold.dart';

/// "Manage news topics": one row per news section (Politics, Business, Sports,
/// World, ...), preselected from the reader's subscriptions.
///
/// The catalogue in `followables.json` mirrors `NewsCategory.all`, so a topic
/// followed here is the same `topic:<categoryId>` id the feed sections and the
/// For You ranking already use.
class ManageTopicsPage extends ConsumerStatefulWidget {
  const ManageTopicsPage({super.key});

  @override
  ConsumerState<ManageTopicsPage> createState() => _ManageTopicsPageState();
}

class _ManageTopicsPageState extends ConsumerState<ManageTopicsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final FollowingSnapshot snapshot = ref.watch(followingControllerProvider);
    final List<FollowTarget> topics = <FollowTarget>[...snapshot.topics]
      ..sort((FollowTarget a, FollowTarget b) => a.label.compareTo(b.label));

    final String query = _query.trim().toLowerCase();
    final List<FollowTarget> visible = query.isEmpty
        ? topics
        : topics
              .where((FollowTarget t) => t.label.toLowerCase().contains(query))
              .toList(growable: false);

    return CataloguePageScaffold(
      title: 'Manage news topics',
      subtitle: 'Select the topics you want to follow.',
      searchHint: 'Search topics',
      onQueryChanged: (String value) => setState(() => _query = value),
      child: visible.isEmpty
          ? const EmptyStateView(
              title: 'No topics found',
              message: 'Try another topic.',
              icon: Icons.search_off,
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: <Widget>[
                CatalogueCard(
                  children: <Widget>[
                    for (final FollowTarget target in visible)
                      CatalogueCheckRow(
                        label: target.label,
                        isSelected: snapshot.isFollowed(target.id),
                        icon: AppGlyphs.category(
                          _topicKey(target.id, target.label),
                        ),
                        onTap: () => ref
                            .read(followingControllerProvider.notifier)
                            .toggle(target),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  /// Topic ids are `topic:<categoryId>`; falling back to the label keeps a
  /// hand-followed target (synced from another device) renderable.
  String _topicKey(String id, String label) {
    if (id.startsWith('topic:')) return id.substring('topic:'.length);
    return label.toLowerCase();
  }
}
