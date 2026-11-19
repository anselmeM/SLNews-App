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
  String? _url;
  bool _failed = false;
  bool _loading = true;

  String get _syncScript {
    if (widget.playback.kind == VideoPlaybackKind.youtube) {
      // The YouTube document owns the player; its IFrame API bridge applies the
      // paused/muted state even if the API is not ready yet.
      return 'window.slnewsSync && window.slnewsSync('
          '${widget.paused}, ${widget.muted});';
    }
    return "(function(){var v=document.querySelector('video');if(!v)return;"
        'v.muted=${widget.muted};'
        "${widget.paused ? 'v.pause();' : 'if(v.paused){v.play&&v.play();}'}"
        '})();';
  }

  @override
  void initState() {
    super.initState();
    _url = widget.playback.embedUrl;
    _controller = WebViewController();
    if (_url == null) {
      _failed = true;
      _loading = false;
      return;
    }
    // Android requires a user gesture before media may start. The reel is a
    // deliberate autoplay surface (muted), so relax the requirement for this
    // controller only; without it the embed opens paused and the JS play() call
    // is rejected.
    if (defaultTargetPlatform == TargetPlatform.android &&
        _controller.platform is AndroidWebViewController) {
      unawaited(
        (_controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false),
      );
    }
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String _) => _update(() => _loading = true),
          // Autoplay and muted state only stick once the player page is up.
          onPageFinished: (String _) {
            _update(() => _loading = false);
            _controller.runJavaScript(_syncScript);
          },
          onWebResourceError: (WebResourceError error) =>
              _update(() => _failed = true),
        ),
      );
    _load();
  }

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
  }

  void _load() {
    final String? url = _url;
    if (url == null) return;
    final String? youtubeId = widget.playback.youtubeId;
    if (widget.playback.kind == VideoPlaybackKind.youtube &&
        youtubeId != null) {
      // Load a document from a real origin instead of the bare embed: YouTube
      // needs a Referer, and a top-level WebView load has none (error 153).
      _controller.loadHtmlString(
        youTubePlayerDocument(youtubeId),
        baseUrl: videoPlayerOrigin,
      );
      return;
    }
    _controller.loadRequest(Uri.parse(url));
  }

  void _retry() {
    setState(() {
      _failed = false;
      _loading = true;
    });
    _load();
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'This video is unavailable right now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: _retry, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        WebViewWidget(controller: _controller),
        if (_loading)
          const Center(
            child: CircularProgressIndicator.adaptive(
              backgroundColor: Colors.white24,
            ),
          ),
      ],
    );
  }
}
