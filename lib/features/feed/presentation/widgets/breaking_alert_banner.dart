import 'package:flutter/material.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Dismissible row shown only while a genuinely fresh breaking story exists.
///
/// The breaking marker used to live permanently beside the weather chip. That
/// made a feed-wide boolean look like a weather label and kept showing after the
/// story had gone stale. This row is deliberately separate: it carries the
/// headline, opens the story, and can be dismissed until a new story arrives.
class BreakingAlertBanner extends StatefulWidget {
  const BreakingAlertBanner({
    super.key,
    required this.article,
    required this.onOpen,
  });

  final Article article;
  final VoidCallback onOpen;

  @override
  State<BreakingAlertBanner> createState() => _BreakingAlertBannerState();
}

class _BreakingAlertBannerState extends State<BreakingAlertBanner> {
  String? _dismissedId;

  @override
  void didUpdateWidget(BreakingAlertBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.article.id != widget.article.id) {
      _dismissedId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissedId == widget.article.id) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Material(
        color: context.colors.live.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.live,
                    borderRadius: AppRadius.pillRadius,
                  ),
                  child: Text(
                    'BREAKING',
                    style: context.typography.overline.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.meta.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _dismissedId = widget.article.id),
                  tooltip: 'Dismiss breaking alert',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: Icon(
                    Icons.close,
                    color: context.colors.onSurfaceVariant,
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
