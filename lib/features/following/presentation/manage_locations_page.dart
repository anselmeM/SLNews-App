import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/follow_models.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_glyphs.dart';
import 'widgets/catalogue_list.dart';

/// "Manage locations": follow up to three cities, as the reference puts behind
/// Following's Locations header.
///
/// The reference caps this at three ("Select up to three locations to follow"),
/// so the fourth tap is refused with a message instead of silently replacing an
/// existing choice. Switching the *home* city stays a separate action — the
/// quick picker on the weather chip and on a followed row — because following a
/// city and reading its weather are different decisions.
class ManageLocationsPage extends ConsumerWidget {
  const ManageLocationsPage({super.key});

  /// The reference's cap on followed locations.
  static const int maxFollowed = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FollowingSnapshot snapshot = ref.watch(followingControllerProvider);
    final List<FollowTarget> locations = <FollowTarget>[
      for (final NewsLocation location in SlLocations.all)
        _targetFor(location, snapshot),
    ];
    final int followedCount = locations
        .where((FollowTarget target) => snapshot.isFollowed(target.id))
        .length;

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
        title: Text('Manage locations', style: context.typography.groupTitle),
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
              'Select up to three locations to follow. ($followedCount/$maxFollowed)',
              style: context.typography.caption,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: <Widget>[
                CatalogueCard(
                  children: <Widget>[
                    for (final FollowTarget target in locations)
                      CatalogueCheckRow(
                        label: target.label,
                        subtitle: target.subtitle,
                        isSelected: snapshot.isFollowed(target.id),
                        icon: AppGlyphs.follow(FollowKind.location),
                        onTap: () => _toggle(context, ref, target),
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

  /// Uses the catalogue entry when the seed carries this city, so a followed
  /// label/region stays authoritative, and builds one otherwise.
  FollowTarget _targetFor(NewsLocation location, FollowingSnapshot snapshot) {
    for (final FollowTarget target in snapshot.locations) {
      if (target.id == location.id) return target;
    }
    return FollowTarget(
      id: location.id,
      kind: FollowKind.location,
      label: location.label,
      subtitle: location.subtitle,
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    FollowTarget target,
  ) async {
    final FollowingSnapshot snapshot = ref.read(followingControllerProvider);
    final bool isFollowing = snapshot.isFollowed(target.id);
    if (!isFollowing) {
      final int followed = snapshot.locations
          .where((FollowTarget t) => snapshot.isFollowed(t.id))
          .length;
      if (followed >= maxFollowed) {
        _notify(
          context,
          'You can follow up to $maxFollowed locations. '
          'Unfollow one to add another.',
        );
        return;
      }
    }
    await ref.read(followingControllerProvider.notifier).toggle(target);
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }
}
