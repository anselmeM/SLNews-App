part of 'sports_page.dart';

/// Large Samsung-style inline ad after the Following row.
Widget _adSliver(BuildContext context, AdUnit unit) {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      child: TrackedAdCard(
        unit: unit,
        onCtaPressed: () =>
            _showSnack(context, 'Sponsored by ${unit.advertiser}'),
        onOpened: (AdUnit opened) =>
            _showSnack(context, 'Sponsored by ${opened.advertiser}'),
      ),
    ),
  );
}

Widget _noticeSliver(
  BuildContext context,
  String message, {
  VoidCallback? onRetry,
}) {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.cardRadius,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.sports_soccer_outlined,
              size: 18,
              color: context.colors.onSurfaceFaint,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.caption,
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}

/// Confirmation surface for the tab's non-destructive actions.
void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Full-bleed lead story at the top of the Sports feed.
class _TopStoryHero extends StatelessWidget {
  const _TopStoryHero({required this.article, required this.onTap});

  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                SlNetworkImage(
                  url: article.imageUrl,
                  fit: BoxFit.cover,
                  placeholderLabel: article.publisher.mark,
                  seed: article.id,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Colors.transparent, Color(0xC7000000)],
                      stops: <double>[0.3, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      PublisherMark(
                        publisher: article.publisher,
                        logoHeight: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.sectionTitle.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                          height: 1.12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.relativeAge,
                        style: context.typography.meta.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
