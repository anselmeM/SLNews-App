import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/data/seed/video_seed.dart';
import '../../../core/domain/models/video_moment.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/video_embed.dart';
import '../../../core/widgets/sl_network_image.dart';

/// Full-screen reel of "Video moments", opened from the feed rail.
///
/// The reference plays a clip in place and lets the reader flick up to the next
/// one, so this is a vertical [PageView] over the same list the rail shows: the
/// tapped clip starts, and swiping continues through the rest. Only the active
/// page holds a web view; the others stay on their thumbnail, which keeps a
/// swipe cheap and stops background players from running.
///
/// Playback is in-app through an embedded player for YouTube links and a plain
/// web view for other publishers' pages. Nothing is opened in a browser unless
/// the reader asks for it, which is the difference from the previous behaviour
/// (`launchUrl` handed the clip straight to the system browser).
/// Resolves the reel's list before building it.
///
/// A route is entered from a URL, so the moments have to come from the provider —
/// and reading a `FutureProvider` inside the page's `initState` would race its
/// first load and silently fall back to the seed. Watching it here means the page
/// always receives a settled list.
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

class VideoReelPage extends StatefulWidget {
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
  State<VideoReelPage> createState() => _VideoReelPageState();
}

class _VideoReelPageState extends State<VideoReelPage> {
  late final PageController _controller;
  int _index = 0;

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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: widget.videos.length,
            onPageChanged: (int index) => setState(() => _index = index),
            itemBuilder: (BuildContext context, int index) {
              final VideoMoment video = widget.videos[index];
              return _ReelItem(
                key: ValueKey<String>(video.id),
                video: video,
                active: index == _index,
                playerBuilder: widget.playerBuilder,
              );
            },
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppSpacing.xs,
            right: AppSpacing.md,
            child: _ReelTopBar(
              position: '${_index + 1}/${widget.videos.length}',
              onClose: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelTopBar extends StatelessWidget {
  const _ReelTopBar({required this.position, required this.onClose});

  final String position;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0x66000000),
            borderRadius: AppRadius.pillRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            child: Text(
              position,
              style: context.typography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: onClose,
          tooltip: 'Close',
          style: IconButton.styleFrom(backgroundColor: const Color(0x66000000)),
          icon: const Icon(Icons.close, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}

class _ReelItem extends StatelessWidget {
  const _ReelItem({
    super.key,
    required this.video,
    required this.active,
    this.playerBuilder,
  });

  final VideoMoment video;
  final bool active;
  final Widget Function(BuildContext context, VideoPlayback playback)?
  playerBuilder;

  @override
  Widget build(BuildContext context) {
    final VideoPlayback playback = resolvePlayback(video.url);

    Widget background;
    if (!playback.isPlayable) {
      background = const _ReelThumbnail(url: '');
    } else if (active) {
      background =
          playerBuilder?.call(context, playback) ??
          _WebVideoPlayer(playback: playback);
    } else {
      background = _ReelThumbnail(url: video.thumbnailUrl);
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: Colors.black, child: background),
        // Scrim so the caption stays readable over any frame of the clip.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0x66000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0xCC000000),
              ],
              stops: <double>[0, 0.25, 0.55, 1],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
          child: _ReelCaption(video: video, playback: playback),
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
class _WebVideoPlayer extends StatefulWidget {
  const _WebVideoPlayer({required this.playback});

  final VideoPlayback playback;

  @override
  State<_WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<_WebVideoPlayer> {
  late final WebViewController _controller;
  bool _failed = false;

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
          onWebResourceError: (WebResourceError error) {
            if (mounted) setState(() => _failed = true);
          },
        ),
      )
      // The player page itself has no other content to load; the request is the
      // embed URL, so a failure here means "offline" or "removed clip".
      ..loadRequest(Uri.parse(url));
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

class _ReelCaption extends StatelessWidget {
  const _ReelCaption({required this.video, required this.playback});

  final VideoMoment video;
  final VideoPlayback playback;

  @override
  Widget build(BuildContext context) {
    final String? summary = video.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.videocam_outlined,
              size: 16,
              color: Color(0xE6FFFFFF),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              video.source,
              style: context.typography.caption.copyWith(
                color: const Color(0xE6FFFFFF),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Deliberately unbounded: a reel has room for the whole caption, and a
        // clipped headline is exactly what the rail could not avoid.
        Text(
          video.title,
          style: context.typography.sectionTitle.copyWith(
            color: Colors.white,
            fontSize: 24,
            height: 1.2,
          ),
        ),
        if (summary != null && summary.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.typography.body.copyWith(
              color: const Color(0xD9FFFFFF),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: <Widget>[
            _ReelAction(
              icon: Icons.ios_share,
              label: 'Share',
              onTap: () => SharePlus.instance.share(
                ShareParams(text: '${video.title} — ${video.url}'),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            if (playback.externalUrl != null)
              _ReelAction(
                icon: Icons.open_in_new,
                label: 'Open',
                onTap: () => launchUrl(
                  Uri.parse(playback.externalUrl!),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReelAction extends StatelessWidget {
  const _ReelAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: context.typography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
