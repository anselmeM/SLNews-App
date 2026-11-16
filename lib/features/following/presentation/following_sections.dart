part of 'following_page.dart';

/// Builds the subscription groups plus their empty/error states.
///
/// `followingControllerProvider` is a synchronous `NotifierProvider`, so its
/// value is available on the first frame and there is no loading branch. A
/// repository failure is reported by the controller as an `AsyncError`, which
/// the error card's retry button recovers from via `ref.invalidate`.
List<Widget> _groupSlivers(
  BuildContext context,
  WidgetRef ref,
  FollowingViewModel viewModel,
) {
  if (viewModel.hasError) {
    return <Widget>[
      SliverPadding(
        padding: AppSpacing.page,
        sliver: SliverToBoxAdapter(
          child: ErrorStateView(
            message: "We couldn't load what you follow.",
            onRetry: () => ref.invalidate(followingControllerProvider),
          ),
        ),
      ),
    ];
  }

  if (viewModel.isLoading && !viewModel.hasError) {
    return const <Widget>[
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          0,
        ),
        sliver: SliverToBoxAdapter(child: _FollowingSkeleton()),
      ),
    ];
  }

  // The four headers always render, as in the reference: each one is the route
  // into its catalogue, so hiding an empty group would leave a reader who
  // follows nothing with no way to start.
  final List<Widget> slivers = <Widget>[
    _sliverSection(
      header: SectionHeader(
        title: FollowKind.team.sectionLabel,
        onTap: () => context.push(AppRoutes.manageSports),
      ),
      child: viewModel.sports.isEmpty
          ? const _EmptyGroupHint('Pick the leagues and teams you follow.')
          : FollowSection(
              targets: viewModel.sports,
              rowBuilder: (BuildContext context, FollowTarget target) =>
                  _entityRow(
                    context,
                    target,
                    onTap: () => _openSports(context, target),
                  ),
            ),
    ),
    _sliverSection(
      header: SectionHeader(
        title: 'Locations',
        onTap: () => context.push(AppRoutes.manageLocations),
      ),
      child: viewModel.locations.isEmpty
          ? const _EmptyGroupHint(
              'Pick up to three cities you want in your feed.',
            )
          : FollowSection(
              targets: viewModel.locations,
              rowBuilder: (BuildContext context, FollowTarget target) =>
                  _entityRow(
                    context,
                    target,
                    invertCircle: true,
                    onTap: () => openLocationPicker(context, ref),
                  ),
            ),
    ),
  ];

  if (viewModel.popularLocations.isNotEmpty) {
    slivers.add(
      _sliverSection(
        header: const FollowGroupLabel(label: 'Most popular with users'),
        child: FollowSection(
          targets: viewModel.popularLocations,
          rowBuilder: (BuildContext context, FollowTarget target) =>
              _suggestedRow(context, ref, target),
        ),
      ),
    );
  }

  slivers.add(
    _sliverSection(
      header: SectionHeader(
        title: 'Topics',
        onTap: () => context.push(AppRoutes.manageTopics),
      ),
      child: viewModel.topics.isEmpty
          ? const _EmptyGroupHint('Pick the news sections you want to follow.')
          : FollowSection(
              targets: viewModel.topics,
              rowBuilder: (BuildContext context, FollowTarget target) =>
                  _entityRow(
                    context,
                    target,
                    leadingIcon: AppGlyphs.category(_topicKey(target)),
                    onTap: () =>
                        context.push(AppRoutes.sectionFor(_topicKey(target))),
                  ),
            ),
    ),
  );

  if (viewModel.suggestedTopics.isNotEmpty) {
    slivers.add(
      _sliverSection(
        header: const FollowGroupLabel(label: 'Based on what you follow'),
        child: FollowSection(
          targets: viewModel.suggestedTopics,
          rowBuilder: (BuildContext context, FollowTarget target) =>
              _suggestedRow(context, ref, target),
        ),
      ),
    );
  }

  slivers.add(
    _sliverSection(
      header: SectionHeader(
        title: 'Sources',
        onTap: () => context.push(AppRoutes.manageSources),
      ),
      child: viewModel.publishers.isEmpty
          ? const _SourcesCaption()
          : FollowSection(
              targets: viewModel.publishers,
              footer: const _SourcesCaption(),
              rowBuilder: (BuildContext context, FollowTarget target) =>
                  _entityRow(
                    context,
                    target,
                    leadingIcon: AppGlyphs.follow(FollowKind.publisher),
                  ),
            ),
    ),
  );

  return slivers;
}

Widget _sliverSection({required Widget header, required Widget child}) {
  return SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    sliver: SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[header, child],
      ),
    ),
  );
}

/// A followed subscription: crest or glyph circle, label, and — following the
/// reference — no trailing chip. The row opens the surface it names.
Widget _entityRow(
  BuildContext context,
  FollowTarget target, {
  IconData? leadingIcon,
  bool invertCircle = false,
  VoidCallback? onTap,
}) {
  final bool hasImage =
      target.imageUrl != null && target.imageUrl!.trim().isNotEmpty;
  final bool inverted = invertCircle && !hasImage;
  return FollowRow(
    label: target.label,
    subtitle: target.subtitle,
    imageUrl: target.imageUrl,
    leadingIcon: hasImage ? null : leadingIcon,
    backgroundColor: inverted ? context.colors.surfaceInverse : null,
    foregroundColor: inverted ? context.colors.onSurfaceInverse : null,
    onTap: onTap,
  );
}

/// Row for a suggestion group: outlined chip that follows it, which also removes
/// it from the list on the next frame.
Widget _suggestedRow(BuildContext context, WidgetRef ref, FollowTarget target) {
  return FollowRow(
    label: target.label,
    subtitle: target.subtitle,
    imageUrl: target.imageUrl,
    // Topic suggestions carry their section glyph, so the row matches the
    // Topics group rather than showing a generic tag.
    leadingIcon: target.kind == FollowKind.topic
        ? AppGlyphs.category(_topicKey(target))
        : AppGlyphs.follow(target.kind),
    trailing: Semantics(
      button: true,
      label: 'Follow ${target.label}',
      child: FollowChip(
        isFollowing: false,
        onPressed: () => _toggle(context, ref, target),
      ),
    ),
  );
}

Future<void> _toggle(
  BuildContext context,
  WidgetRef ref,
  FollowTarget target,
) async {
  await ref.read(followingControllerProvider.notifier).toggle(target);
  if (!context.mounted) return;
  final bool isFollowing = ref
      .read(followingControllerProvider)
      .isFollowed(target.id);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '${isFollowing ? 'Following' : 'Unfollowed'} ${target.label}',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
}

/// Opens the league or team surface behind a followed sports row.
void _openSports(BuildContext context, FollowTarget target) {
  final String id = _identifier(target);
  if (target.kind == FollowKind.league) {
    context.push(AppRoutes.leagueFor(id));
    return;
  }
  context.push(AppRoutes.teamFor(id));
}

/// Topic targets are `topic:<categoryId>`; the section route wants the bare id.
String _topicKey(FollowTarget target) => _identifier(target);

/// Strips the `<kind>:` prefix from a follow id (`team:lal` -> `lal`).
String _identifier(FollowTarget target) {
  final int separator = target.id.indexOf(':');
  if (separator < 0 || separator == target.id.length - 1) return target.id;
  return target.id.substring(separator + 1);
}

/// One-line prompt shown in place of an empty group's card.
class _EmptyGroupHint extends StatelessWidget {
  const _EmptyGroupHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        right: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Text(message, style: context.typography.caption),
    );
  }
}

/// The reference's one-line explanation under the Sources group.
class _SourcesCaption extends StatelessWidget {
  const _SourcesCaption();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        left: AppSpacing.xs,
        right: AppSpacing.xs,
      ),
      child: Text(
        'Get news from the sources you trust at the top of your feed.',
        style: context.typography.caption,
      ),
    );
  }
}
