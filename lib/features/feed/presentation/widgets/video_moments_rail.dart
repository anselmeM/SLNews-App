import 'package:flutter/material.dart';

import '../../../../core/domain/models/video_moment.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/video_moment_card.dart';

/// Horizontal "Video moments" carousel: portrait cards, peeking the next one so
/// the row reads as scrollable, exactly like the reference.
class VideoMomentsRail extends StatelessWidget {
  const VideoMomentsRail({super.key, required this.videos, this.onOpen});

  final List<VideoMoment> videos;
  final ValueChanged<VideoMoment>? onOpen;

  /// Card height plus the rail's own vertical breathing room.
  static const double railHeight = 268;

  /// The rail is a taste, not the archive: 12 clips travel with the page, the
  /// reel still gets the whole fetched rotation.
  static const int maxCards = 12;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: railHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: videos.length > maxCards ? maxCards : videos.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) {
          final VideoMoment video = videos[index];
          return VideoMomentCard(
            video: video,
            onTap: onOpen == null ? null : () => onOpen!(video),
          );
        },
      ),
    );
  }
}
