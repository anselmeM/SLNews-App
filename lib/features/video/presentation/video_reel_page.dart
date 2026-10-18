import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/data/seed/video_seed.dart';
import '../../../core/domain/models/video_moment.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/video_embed.dart';
import '../../../core/widgets/sl_network_image.dart';
import '../../../core/utils/motion.dart';

/// Full-screen reel of "Video moments", opened from the feed rail.
///
/// Layout follows the reference player: the clip is full-bleed, a back chevron
/// sits top-left, a vertical action rail (mute, full screen, like) hangs
/// bottom-right, the outlet's badge sits bottom-left, and a white strip
/// underneath carries the caption over a segmented position indicator. Swiping
/// up moves to the next clip in the same list the rail shows; only the active
/// page holds a player, so a swipe stays cheap and nothing plays in the
/// background.
class VideoReelRoute extends ConsumerWidget {
  const VideoReelRoute({super.key, required this.videoId, this.playerBuilder});

  final String videoId;

  /// Test seam, forwarded to the page.
  final Widget Function(BuildContext context, VideoPlayback playback)?
  playerBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<VideoMoment>? live = ref.watch(videoMomentsProvider).value;
    // The rail always has something to show — live rows when configured, the
    // bundled rotation otherwise — so the reel can never open empty.
    final List<VideoMoment> videos = (live != null && live.isNotEmpty)
        ? live
        : SlVideos.all;
    return VideoReelPage(
      videos: videos,
      videoId: videoId,
      playerBuilder: playerBuilder,
    );
  }
}

class VideoReelPage extends ConsumerStatefulWidget {
  const VideoReelPage({
    super.key,
    required this.videos,
    required this.videoId,
    this.playerBuilder,
  });

  /// The moments to flick through, in order.
  final List<VideoMoment> videos;

  /// Id of the moment to start on; unknown ids start at the top.
  final String videoId;

  /// Test seam: replaces the real web-view player (platform views cannot be
  /// driven in widget tests).
  final Widget Function(BuildContext context, VideoPlayback playback)?
  playerBuilder;

  @override
  ConsumerState<VideoReelPage> createState() => _VideoReelPageState();
}

class _VideoReelPageState extends ConsumerState<VideoReelPage> {
  late final PageController _controller;
  int _index = 0;
  bool _paused = false;
  bool _muted = false;
  bool _immersive = false;

  @override
  void initState() {
    super.initState();
    final int found = widget.videos.indexWhere(
      (VideoMoment video) => video.id == widget.videoId,
    );
    _index = found < 0 ? 0 : found;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _controller.dispose();
    super.dispose();
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    SystemChrome.setEnabledSystemUIMode(
      _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _moreSheet(VideoMoment video) async {
    final VideoPlayback playback = resolvePlayback(video.url);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                SharePlus.instance.share(
                  ShareParams(text: '${video.title} — ${video.url}'),
                );
              },
            ),
            if (playback.externalUrl != null)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Open in browser'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  launchUrl(
                    Uri.parse(playback.externalUrl!),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Set<String> liked = ref.watch(likesControllerProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: (int index) => setState(() {
          _index = index;
          // A new clip starts playing, so the old pause state must not carry over.
          _paused = false;
        }),
        itemBuilder: (BuildContext context, int index) {
          final VideoMoment video = widget.videos[index];
          final bool active = index == _index;
          return _ReelPage(
            key: ValueKey<String>(video.id),
            video: video,
            active: active,
            paused: active && _paused,
            muted: _muted,
            liked: liked.contains(video.id),
            position: index + 1,
            total: widget.videos.length,
            immersive: _immersive,
            playerBuilder: widget.playerBuilder,
            onTogglePause: () => setState(() => _paused = !_paused),
            onToggleMute: () => setState(() => _muted = !_muted),
            onToggleImmersive: _toggleImmersive,
            onLike: () =>
                ref.read(likesControllerProvider.notifier).toggle(video.id),
            onBack: () => Navigator.of(context).maybePop(),
            onMore: () => _moreSheet(video),
          );
        },
      ),
    );
  }
}

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
    final VideoPlayback playback = resolvePlayback(video.url);

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

/// Segmented position indicator, one segment per clip.
///
/// Public so the reel tests can assert the position without reaching into
/// private widget state.
@visibleForTesting
class ReelSegments extends StatelessWidget {
  const ReelSegments({super.key, required this.position, required this.total});

  final int position;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int index = 0; index < total; index++)
          Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: index == position - 1
                    ? context.colors.onSurface
                    : context.colors.divider,
                borderRadius: AppRadius.pillRadius,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReelThumbnail extends StatelessWidget {
  const _ReelThumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return const ColoredBox(color: Color(0xFF101010));
    return SlNetworkImage(
      url: url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }
}

/// The embedded player: YouTube via its embed URL, other outlets' pages as-is.
///
/// Playback state is applied through JavaScript because the clip plays inside a
/// web view: the embed's own `<video>` element is the only handle on it, and the
/// reference's controls (tap to pause, mute) drive that same element.
class _WebVideoPlayer extends StatefulWidget {
  const _WebVideoPlayer({
    required this.playback,
    required this.paused,
    required this.muted,
  });

  final VideoPlayback playback;
  final bool paused;
  final bool muted;

  @override
  State<_WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<_WebVideoPlayer> {
  late final WebViewController _controller;
  bool _failed = false;

  String get _syncScript =>
      "(function(){var v=document.querySelector('video');if(!v)return;"
      'v.muted=${widget.muted};'
      "${widget.paused ? 'v.pause();' : 'if(v.paused){v.play&&v.play();}'}"
      '})();';

  @override
  void initState() {
    super.initState();
    final String? url = widget.playback.embedUrl;
    _controller = WebViewController();
    if (url == null) {
      _failed = true;
      return;
    }
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          // Autoplay and muted state only stick once the player page is up.
          onPageFinished: (String _) => _controller.runJavaScript(_syncScript),
          onWebResourceError: (WebResourceError error) {
            if (mounted) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  void didUpdateWidget(_WebVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused || oldWidget.muted != widget.muted) {
      _controller.runJavaScript(_syncScript);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text(
          'This video is unavailable right now.',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
        ),
      );
    }
    return WebViewWidget(controller: _controller);
  }
}
