import 'package:flutter/material.dart';

import '../domain/models/ad_unit.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'sl_network_image.dart';

/// Native-style inline ad unit.
///
/// The creative is painted locally (brand gradient + simulated offer card) so
/// the unit renders identically offline, always carries the `Ad` label and
/// disclosure line, and never masquerades as editorial content.
class AdCard extends StatelessWidget {
  const AdCard({
    super.key,
    required this.unit,
    this.onCtaPressed,
    this.onOpened,
  });

  final AdUnit unit;
  final VoidCallback? onCtaPressed;
  final ValueChanged<AdUnit>? onOpened;

  @override
  Widget build(BuildContext context) {
    final Color start = _parseHex(
      unit.brandAccentHex,
      context.colors.accentGradientStart,
    );
    final Color end = _parseHex(
      unit.brandHex,
      context.colors.accentGradientEnd,
    );
    return Semantics(
      label: 'Advertisement: ${unit.advertiser}',
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: () {
                if (onOpened != null) {
                  onOpened!(unit);
                } else {
                  onCtaPressed?.call();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[start, end],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Stack(
                  children: <Widget>[
                    // Optional sold-creative image sits under the copy. A
                    // stronger scrim keeps white text readable on photos.
                    if (unit.imageUrl != null && unit.imageUrl!.isNotEmpty)
                      Positioned.fill(
                        child: SlNetworkImage(
                          url: unit.imageUrl,
                          fit: BoxFit.cover,
                          placeholderLabel: unit.advertiser,
                          seed: unit.id,
                        ),
                      ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: unit.imageUrl != null
                                ? const <Color>[
                                    Color(0x66000000),
                                    Color(0x99000000),
                                    Color(0xCC000000),
                                  ]
                                : const <Color>[
                                    Color(0x00000000),
                                    Color(0x0D000000),
                                    Color(0x33000000),
                                  ],
                            stops: const <double>[0, 0.55, 1],
                          ),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          unit.headline,
                          style: context.typography.sectionTitle.copyWith(
                            color: Colors.white,
                            fontSize: 24,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (unit.assetLabel != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          Center(child: _OfferCard(unit: unit)),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: <Widget>[
                            Text(
                              'AD',
                              style: context.typography.overline.copyWith(
                                color: const Color(0xCCFFFFFF),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(
                              Icons.info_outline,
                              size: 13,
                              color: Color(0xCCFFFFFF),
                            ),
                          ],
                        ),
                        if (unit.disclosure != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            unit.disclosure!,
                            style: context.typography.overline.copyWith(
                              color: const Color(0x99FFFFFF),
                              letterSpacing: 0,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      unit.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.button,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton(
                    onPressed: onCtaPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.surfaceMuted,
                      foregroundColor: context.colors.onSurface,
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(15)),
                      ),
                    ),
                    child: Text(unit.ctaLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _parseHex(String hex, Color fallback) {
    final String cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return fallback;
    final int? value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(0xFF000000 | value);
  }
}

/// The white "offer" card drawn inside the brand panel, e.g. "$20 PayPal"-style
/// creative. Uses the advertiser name as the mark so no third-party brand asset
/// is required.
class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.unit});

  final AdUnit unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              unit.advertiser,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.button.copyWith(
                color: const Color(0xFF0B3F73),
                fontSize: 17,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // The headline figure shrinks rather than overflowing a 320pt screen
          // at a 1.3x text scale.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                unit.assetLabel!,
                style: context.typography.screenTitle.copyWith(
                  color: const Color(0xFF1B2A6B),
                  fontSize: 38,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
