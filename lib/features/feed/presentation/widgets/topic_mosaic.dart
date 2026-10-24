import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/sl_network_image.dart';

/// One image topic card in the Following mosaic.
@immutable
class TopicMosaicItem {
  const TopicMosaicItem({
    required this.id,
    required this.label,
    this.icon = 'topic',
    this.imageUrl,
  });

  final String id;
  final String label;

  /// Icon key used when the category has no story image yet.
  final String icon;

  final String? imageUrl;
}

/// Two-column mosaic of image topic cards, as the reference shows under
/// "Following ›": a photo (or a glyph placeholder), a scrim and the topic name.
///
/// The card is the tap target; [onOpen] receives the whole item so the caller can
/// navigate to that topic's section page without a lookup by id.
class TopicMosaic extends StatelessWidget {
  const TopicMosaic({
    super.key,
    required this.items,
    this.onOpen,
    this.maxItems = 4,
  });

  final List<TopicMosaicItem> items;
  final ValueChanged<TopicMosaicItem>? onOpen;

  /// The reference shows four cards above the fold; extra topics are skipped so
  /// the rail never becomes a second feed.
  final int maxItems;

  // Samsung cover_2x2 is 150x133 dp (1.128).
  static const double _aspectRatio = 1.13;

  @override
  Widget build(BuildContext context) {
    final List<TopicMosaicItem> visible = items
        .take(maxItems)
        .toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: _aspectRatio,
      ),
      itemBuilder: (BuildContext context, int index) => _TopicCard(
        item: visible[index],
        onTap: onOpen == null ? null : () => onOpen!(visible[index]),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.item, this.onTap});

  final TopicMosaicItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasImage = item.imageUrl?.trim().isNotEmpty ?? false;
    return Semantics(
      container: true,
      button: true,
      label: 'Open ${item.label}',
      child: Material(
        color: context.colors.surfaceInverse,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (hasImage)
                SlNetworkImage(url: item.imageUrl, placeholderLabel: item.label)
              else
                Center(
                  child: Icon(
                    _topicIcon(item.icon),
                    size: 32,
                    color: context.colors.onSurfaceInverse,
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x00000000), Color(0xB3000000)],
                    stops: <double>[0.35, 1],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.groupTitle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Material glyph for a category icon key. Unknown keys fall back to a tag.
IconData _topicIcon(String key) => switch (key) {
  'politics' => Icons.account_balance_outlined,
  'business' => Icons.trending_up,
  'cars' => Icons.directions_car_outlined,
  'music' => Icons.music_note_outlined,
  'culture' => Icons.palette_outlined,
  'sports' => Icons.sports_soccer,
  'health' => Icons.health_and_safety_outlined,
  'tech' => Icons.memory,
  'education' => Icons.school_outlined,
  'mining' => Icons.landscape_outlined,
  'world' => Icons.public,
  _ => Icons.tag,
};
