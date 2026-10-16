import 'package:flutter/material.dart';

import '../../../../core/domain/models/notification_item.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_glyphs.dart';

/// One alert in the notification history list.
///
/// Geometry follows the reader-facing list language: a fixed 40pt kind-icon
/// circle, a bold title, a two-line body, the relative age on the right and an
/// unread dot for alerts that have not been opened yet.
class NotificationHistoryRow extends StatelessWidget {
  const NotificationHistoryRow({super.key, required this.item, this.onTap});

  final NotificationItem item;

  /// Called with the item tapped; the page marks it read and deep-links.
  final ValueChanged<NotificationItem>? onTap;

  /// Diameter of the leading kind-icon circle.
  static const double circleSize = 40;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(item),
        child: Padding(
          padding: AppSpacing.row,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: circleSize,
                height: circleSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppGlyphs.notification(item.kind.wireValue),
                  size: 20,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.cardTitleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.body.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(item.ageLabel, style: context.typography.meta),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Fixed-size slot so read/unread never changes the row width.
              SizedBox(
                width: 8,
                height: AppSpacing.lg,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Semantics(
                    label: item.isRead ? 'Read' : 'Unread',
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.isRead ? Colors.transparent : context.colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
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
