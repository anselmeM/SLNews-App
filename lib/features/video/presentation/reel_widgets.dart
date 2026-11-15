part of 'video_reel_page.dart';

class _ReelPage extends StatelessWidget {
  const _ReelPage({
    super.key,
    required this.video,
    required this.active,
    required this.paused,
    required this.muted,
    required this.liked,
    required this.position,
    required this.total,
    required this.immersive,
    required this.onTogglePause,
    required this.onToggleMute,
    required this.onToggleImmersive,
    required this.onLike,
    required this.onBack,
    required this.onMore,
    this.playerBuilder,
  });

  final VideoMoment video;
  final bool active;
  final bool paused;
  final bool muted;
  final bool liked;
  final int position;
  final int total;
  final bool immersive;
  final VoidCallback onTogglePause;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleImmersive;
  final VoidCallback onLike;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final Widget Function(BuildContext context, VideoPlayback playback)?
  playerBuilder;

  @override
  Widget build(BuildContext context) {
    final VideoPlayback playback = resolvePlayback(
      video.url,
      knownId: video.youtubeId,
    );

    Widget media;
    if (!playback.isPlayable) {
      media = _ReelThumbnail(url: video.thumbnailUrl);
    } else if (active) {
      media =
          playerBuilder?.call(context, playback) ??
          _WebVideoPlayer(playback: playback, paused: paused, muted: muted);
    } else {
      media = _ReelThumbnail(url: video.thumbnailUrl);
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: Colors.black, child: media),
              // Tap anywhere on the clip to play or pause, like the reference.
              if (playback.isPlayable)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTogglePause,
                  child: const SizedBox.expand(),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !paused,
                  child: AnimatedSwitcher(
                    duration: motionDuration(context, AppMotion.fast),
                    child: paused
                        // Tapping the play control must resume too: it sits over
                        // the centre of the clip, so it gets its own tap target
                        // instead of passing the event to the layer below.
                        ? GestureDetector(
                            key: const ValueKey<String>('reel-paused'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onTogglePause,
                            child: const Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0x59000000),
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(AppSpacing.lg),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 44,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey<String>('reel-playing'),
                          ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + AppSpacing.xs,
                left: AppSpacing.xs,
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                    shadows: <Shadow>[
                      Shadow(color: Color(0x8A000000), blurRadius: 6),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.sm,
                bottom: immersive ? AppSpacing.xl : AppSpacing.lg,
                child: _ReelActionRail(
                  muted: muted,
                  liked: liked,
                  immersive: immersive,
                  onToggleMute: onToggleMute,
                  onToggleLike: onLike,
                  onToggleImmersive: onToggleImmersive,
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                bottom: immersive
                    ? MediaQuery.paddingOf(context).bottom + AppSpacing.md
                    : AppSpacing.md,
                right: AppSpacing.xxl + AppSpacing.lg,
                child: _PublisherBadge(source: video.source),
              ),
            ],
          ),
        ),
        if (!immersive)
          _ReelCaptionStrip(
            title: video.title,
            position: position,
            total: total,
            onMore: onMore,
          ),
      ],
    );
  }
}

/// Mute, full screen and like — the reference's vertical rail over the clip.
class _ReelActionRail extends StatelessWidget {
  const _ReelActionRail({
    required this.muted,
    required this.liked,
    required this.immersive,
    required this.onToggleMute,
    required this.onToggleLike,
    required this.onToggleImmersive,
  });

  final bool muted;
  final bool liked;
  final bool immersive;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleImmersive;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _RailButton(
          icon: muted ? Icons.volume_off : Icons.volume_up,
          semanticLabel: muted ? 'Unmute' : 'Mute',
          onTap: onToggleMute,
        ),
        const SizedBox(height: AppSpacing.md),
        _RailButton(
          icon: immersive ? Icons.close_fullscreen : Icons.open_in_full,
          semanticLabel: immersive ? 'Exit full screen' : 'Full screen',
          onTap: onToggleImmersive,
        ),
        const SizedBox(height: AppSpacing.md),
        _RailButton(
          icon: liked ? Icons.thumb_up : Icons.thumb_up_outlined,
          semanticLabel: liked ? 'Unlike' : 'Like',
          onTap: onToggleLike,
        ),
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 26,
          shadows: const <Shadow>[
            Shadow(color: Color(0x8A000000), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

/// The outlet, bottom-left over the clip: a monogram disc plus its name.
class _PublisherBadge extends StatelessWidget {
  const _PublisherBadge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final String name = source.trim().isEmpty ? 'SLNews' : source.trim();
    final String initial = name.substring(0, 1).toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xEBFFFFFF),
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: context.typography.caption.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.typography.cardTitleSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              shadows: const <Shadow>[
                Shadow(color: Color(0x8A000000), blurRadius: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// White strip under the clip: caption, then the segmented indicator.
class _ReelCaptionStrip extends StatelessWidget {
  const _ReelCaptionStrip({
    required this.title,
    required this.position,
    required this.total,
    required this.onMore,
  });

  final String title;
  final int position;
  final int total;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.cardTitleSmall.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onMore,
                  tooltip: 'More',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            ReelSegments(position: position, total: total),
          ],
        ),
      ),
    );
  }
}
