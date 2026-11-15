part of 'video_reel_page.dart';

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
