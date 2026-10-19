import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/follow_models.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/state_views.dart';

/// "Manage news topics": the checkmarked topic catalogue from the reference.
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
    final List<FollowTarget> topics =
        <FollowTarget>[
          ...snapshot.followed,
          ...snapshot.suggested,
        ].where((FollowTarget t) => t.kind == FollowKind.topic).toList()..sort(
          (FollowTarget a, FollowTarget b) => a.label.compareTo(b.label),
        );

    final String query = _query.trim().toLowerCase();
    final List<FollowTarget> visible = query.isEmpty
        ? topics
        : topics
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
        title: Text('Manage news topics', style: context.typography.groupTitle),
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
                hintText: 'Search topics',
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const EmptyStateView(
                    title: 'No topics found',
                    message: 'Try another topic.',
                    icon: Icons.search_off,
                  )
                : ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (BuildContext context, int index) {
                      final FollowTarget target = visible[index];
                      final bool following = snapshot.isFollowed(target.id);
                      return CheckboxListTile(
                        value: following,
                        onChanged: (_) => ref
                            .read(followingControllerProvider.notifier)
                            .toggle(target),
                        title: Text(target.label),
                        subtitle: target.subtitle == null
                            ? null
                            : Text(target.subtitle!),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
