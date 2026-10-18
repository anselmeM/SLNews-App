import 'package:flutter/material.dart';

import '../domain/models/video_moment.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'pressable_ink_well.dart';
import 'sl_network_image.dart';

/// Portrait video card used by the "Video moments" rail.
///
/// Mirrors the reference: a tall thumbnail, a caption over a bottom scrim and the
/// publisher underneath, with a play affordance. Sizes come from the design
/// tokens so it holds up at 320pt and at large text scales.
class VideoMomentCard extends StatelessWidget {
  const VideoMomentCard({
    super.key,
    required this.video,
    this.onTap,
    this.width = 152,
    this.height = 268,
  });

  final VideoMoment video;
  final VoidCallback? onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${video.title}. ${video.source}. Video.',
      child: PressableInkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: ClipRRect(
          borderRadius: AppRadius.cardRadius,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (video.thumbnailUrl.isNotEmpty)
                  SlNetworkImage(
                    url: video.thumbnailUrl,
                    width: width,
                    height: height,
                    placeholderLabel: video.source,
                  )
                else
                  ColoredBox(color: context.colors.surfaceMuted),
                // Readability scrim for the caption: the thumbnail underneath is
                // arbitrary, so the text always sits on its own gradient.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Color(0x00000000),
                        Color(0xB3000000),
                        Color(0xE6000000),
                      ],
                      stops: <double>[0, 0.42, 0.72, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: const BoxDecoration(
                      color: Color(0x66000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        video.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: context.typography.cardTitleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          // The reference puts the outlet's mark here rather than a
                          // generic camera glyph; a monogram disc stands in for the
                          // logo the payload does not carry.
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xF2FFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _initial(video.source),
                              style: context.typography.caption.copyWith(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              video.source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typography.caption.copyWith(
                                color: const Color(0xE6FFFFFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (video.duration != null) ...<Widget>[
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              durationLabel(video.duration!),
                              style: context.typography.caption.copyWith(
                                color: const Color(0xB3FFFFFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
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

/// First letter of the outlet name, for the monogram disc.
String _initial(String source) {
  final String trimmed = source.trim();
  return trimmed.isEmpty ? 'S' : trimmed.substring(0, 1).toUpperCase();
}

/// "1:05" / "1:02:03" - the shape a clip length reads in.
@visibleForTesting
String durationLabel(Duration duration) {
  final int minutes = duration.inMinutes;
  final int seconds = duration.inSeconds % 60;
  if (minutes >= 60) {
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    return '$hours:${rest.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
