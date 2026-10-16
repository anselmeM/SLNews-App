import 'package:flutter/material.dart';

import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_glyphs.dart';
import '../../../../core/widgets/sl_network_image.dart';

/// One row inside a Following card group: fixed-size leading circle, a title
/// with an optional subtitle, and a caller-supplied trailing control.
///
/// The leading circle is one of three things, always at the same size so the
/// list never shifts while an image loads:
/// * the crest via `SlNetworkImage` when [FollowTarget.imageUrl] is present,
/// * a filled [backgroundColor] circle with a Material glyph,
/// * a filled circle with the label initials (`AppGlyphs.initials`).
///
/// [onTap] makes the whole row (except the trailing control, which keeps its own
/// gesture) interactive.
class FollowRow extends StatelessWidget {
  const FollowRow({
    super.key,
    required this.label,
    this.subtitle,
    this.imageUrl,
    this.leadingIcon,
    this.initials,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;

  /// Secondary line, e.g. "Basketball · NBA" or "Freetown, SL".
  final String? subtitle;

  /// Crest / avatar URL; rendered through `SlNetworkImage` when non-null.
  final String? imageUrl;

  /// Glyph drawn in the leading circle when there is no [imageUrl]. Falls back
  /// to [initials] when null.
  final IconData? leadingIcon;

  /// Explicit initials override; defaults to `AppGlyphs.initials(label)`.
  final String? initials;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// Leading circle fill. Defaults to `surfaceMuted`.
  final Color? backgroundColor;

  /// Leading glyph/initials colour. Defaults to `onSurface`.
  final Color? foregroundColor;

  /// Diameter of the leading circle (44pt keeps the row a legal tap target).
  static const double circleSize = 44;

  @override
  Widget build(BuildContext context) {
    final Widget row = Padding(
      padding: AppSpacing.row,
      child: Row(
        children: <Widget>[
          _LeadingCircle(
            label: label,
            imageUrl: imageUrl,
            icon: leadingIcon,
            initials: initials,
            backgroundColor: backgroundColor ?? context.colors.surfaceMuted,
            foregroundColor: foregroundColor ?? context.colors.onSurface,
            semanticsLabel: subtitle == null ? label : '$label, $subtitle',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typography.groupTitle,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.caption,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            // The label column already absorbs slack, so a trailing control only
            // overflows at very narrow widths with large text. Shrinking it is
            // preferable to clipping a control the reader needs to tap.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Fixed-size leading avatar: remote crest, glyph circle or initials circle.
class _LeadingCircle extends StatelessWidget {
  const _LeadingCircle({
    required this.label,
    required this.imageUrl,
    required this.icon,
    required this.initials,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.semanticsLabel,
  });

  final String label;
  final String? imageUrl;
  final IconData? icon;
  final String? initials;
  final Color backgroundColor;
  final Color foregroundColor;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    if (hasImage) {
      return SlNetworkImage(
        url: imageUrl,
        width: FollowRow.circleSize,
        height: FollowRow.circleSize,
        borderRadius: const BorderRadius.all(Radius.circular(FollowRow.circleSize / 2)),
        placeholderLabel: AppGlyphs.initials(label),
      );
    }

    return Semantics(
      label: semanticsLabel,
      child: Container(
        width: FollowRow.circleSize,
        height: FollowRow.circleSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
        child: icon != null
            ? Icon(icon, size: 20, color: foregroundColor)
            : Text(
                initials ?? AppGlyphs.initials(label),
                style: context.typography.button.copyWith(color: foregroundColor),
              ),
      ),
    );
  }
}
