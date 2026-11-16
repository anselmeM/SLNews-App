import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/follow_models.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_glyphs.dart';
import '../../../core/widgets/state_views.dart';
import 'widgets/catalogue_list.dart';

/// "Manage news sources": every publisher SLNews aggregates, with the reader's
/// subscriptions preselected.
///
/// The list comes from the full catalogue (`snapshot.publishers`), not from
/// "followed plus suggested": suggestions are the popular subset, and publishers
/// are never marked popular, so the old source list was empty until a reader had
/// already followed something they could not reach.
class ManageSourcesPage extends ConsumerStatefulWidget {
  const ManageSourcesPage({super.key});

  @override
  ConsumerState<ManageSourcesPage> createState() => _ManageSourcesPageState();
}

class _ManageSourcesPageState extends ConsumerState<ManageSourcesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final FollowingSnapshot snapshot = ref.watch(followingControllerProvider);
    final List<FollowTarget> sources = <FollowTarget>[...snapshot.publishers]
      ..sort((FollowTarget a, FollowTarget b) => a.label.compareTo(b.label));

    final String query = _query.trim().toLowerCase();
    final List<FollowTarget> visible = query.isEmpty
        ? sources
        : sources
              .where((FollowTarget t) => t.label.toLowerCase().contains(query))
              .toList(growable: false);

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Manage news sources',
          style: context.typography.groupTitle,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(
              'Select the sources you want at the top of your feed.',
              style: context.typography.caption,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              onChanged: (String value) => setState(() => _query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search sources',
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const EmptyStateView(
                    title: 'No sources found',
                    message: 'Try another name.',
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
                              subtitle: target.subtitle,
                              isSelected: snapshot.isFollowed(target.id),
                              initials: AppGlyphs.initials(target.label),
                              onTap: () => ref
                                  .read(followingControllerProvider.notifier)
                                  .toggle(target),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
