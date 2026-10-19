import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/follow_models.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/follow_chip.dart';
import '../../../core/widgets/state_views.dart';
import 'widgets/follow_row.dart';

/// "Manage news sources": the searchable publisher catalogue with Follow chips,
/// as the reference puts behind Following → Sources.
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
    final List<FollowTarget> sources =
        <FollowTarget>[
            ...snapshot.followed,
            ...snapshot.suggested,
          ].where((FollowTarget t) => t.kind == FollowKind.publisher).toList()
          ..sort(
            (FollowTarget a, FollowTarget b) => a.label.compareTo(b.label),
          );

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
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
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
                : ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: context.colors.divider),
                    itemBuilder: (BuildContext context, int index) {
                      final FollowTarget target = visible[index];
                      final bool following = snapshot.isFollowed(target.id);
                      return FollowRow(
                        label: target.label,
                        subtitle: target.subtitle,
                        imageUrl: target.imageUrl,
                        initials: target.label,
                        trailing: FollowChip(
                          isFollowing: following,
                          dense: true,
                          onPressed: () => ref
                              .read(followingControllerProvider.notifier)
                              .toggle(target),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
