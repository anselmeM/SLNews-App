import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/data/seed/video_seed.dart';
import '../../../core/domain/models/video_moment.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/video_likes_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/config/l10n.dart';
import '../../../core/utils/video_embed.dart';
import '../../../core/widgets/sl_network_image.dart';
import '../../../core/utils/app_log.dart';
import '../../../core/utils/motion.dart';

import 'package:youtube_player_iframe/youtube_player_iframe.dart';

part 'reel_widgets.dart';
part 'web_video_player.dart';

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
  final Widget Function(
    BuildContext context,
    VideoPlayback playback,
    VoidCallback onTogglePause,
  )?
  playerBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<VideoMoment> live = ref.watch(videoMomentsProvider);
    // The rail always has something to show — live rows when configured, the
    // bundled rotation otherwise — so the reel can never open empty.
    final List<VideoMoment> videos = live.isNotEmpty ? live : SlVideos.all;
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
  final Widget Function(
    BuildContext context,
    VideoPlayback playback,
    VoidCallback onTogglePause,
  )?
  playerBuilder;

  @override
  ConsumerState<VideoReelPage> createState() => _VideoReelPageState();
}

class _VideoReelPageState extends ConsumerState<VideoReelPage> {
  late final PageController _controller;
  int _index = 0;
  bool _paused = false;

  /// Start muted: browsers only allow autoplay when it is silent, and the reel
  /// is an autoplay surface. The rail's speaker control unmutes on demand.
  bool _muted = true;
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
    final VideoPlayback playback = resolvePlayback(
      video.url,
      knownId: video.youtubeId,
    );
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
    final Set<String> liked = ref.watch(videoLikesProvider);

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
                ref.read(videoLikesProvider.notifier).toggle(video.id),
            onBack: () => Navigator.of(context).maybePop(),
            onMore: () => _moreSheet(video),
          );
        },
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
