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
    required this.onTogglePause,
  });

  final VideoPlayback playback;
  final bool paused;
  final bool muted;
  final VoidCallback onTogglePause;

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

  @override
  void didUpdateWidget(_WebVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused != widget.paused || oldWidget.muted != widget.muted) {
      unawaited(_controller.runJavaScript(_syncScript));
    }
  }

  void _load() {
    final String? url = _url;
    if (url == null) return;
    unawaited(_controller.loadRequest(Uri.parse(url)));
  }

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
  }

  void _retry() {
    if (_url == null) return;
    setState(() {
      _failed = false;
      _loading = true;
    });
    _load();
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
              Text(
                context.l10n.videoUnavailable,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: _retry, child: Text(context.l10n.tryAgain)),
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        WebViewWidget(controller: _controller),
        // Sits below the loading spinner but above the page, so a tap pauses
        // without swallowing interactions the page itself renders.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTogglePause,
          child: const SizedBox.expand(),
        ),
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

/// Native YouTube surface for the reel.
///
/// The plugin owns the iframe API, so fullscreen, captions (the embed's caption
/// track is enabled by default) and playback state go through its controller
/// instead of injected JavaScript. Anything the plugin cannot play falls back to
/// the WebView player through [onUnavailable], so a plugin regression cannot
/// blank the reel.
class _YoutubeReelPlayer extends StatefulWidget {
  const _YoutubeReelPlayer({
    required this.videoId,
    required this.active,
    required this.paused,
    required this.muted,
    required this.onTogglePause,
    this.onUnavailable,
  });

  final String videoId;
  final bool active;
  final bool paused;
  final bool muted;
  final VoidCallback onTogglePause;

  /// Called once when the plugin reports an error, so the caller can fall back.
  final VoidCallback? onUnavailable;

  @override
  State<_YoutubeReelPlayer> createState() => _YoutubeReelPlayerState();
}

class _YoutubeReelPlayerState extends State<_YoutubeReelPlayer> {
  late YoutubePlayerController _controller;
  StreamSubscription<YoutubePlayerValue>? _values;
  bool _captionsEnabled = true;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open({double? startSeconds, bool? captions}) {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: widget.active && !widget.paused,
      startSeconds: startSeconds,
      params: YoutubePlayerParams(
        mute: true,
        enableCaption: captions ?? _captionsEnabled,
        captionLanguage: 'en',
        interfaceLanguage: 'en',
        showControls: false,
        showFullscreenButton: true,
        playsInline: true,
        strictRelatedVideos: true,
        privacyEnhancedMode: true,
        origin: 'https://slnews.sl',
      ),
    );
    _values = _controller.stream.listen((YoutubePlayerValue value) {
      if (!value.hasError || !mounted) return;
      AppLog.debug('YouTube player error: ${value.error}');
      widget.onUnavailable?.call();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyState());
  }

  @override
  void didUpdateWidget(_YoutubeReelPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyState();
  }

  Future<void> _applyState() async {
    if (!mounted) return;
    try {
      if (!widget.active || widget.paused) {
        await _controller.pauseVideo();
      } else {
        await _controller.playVideo();
      }
      if (widget.muted) {
        await _controller.mute();
      } else {
        await _controller.unMute();
      }
    } catch (error) {
      AppLog.debug('YouTube player state change failed: $error');
    }
  }

  /// YouTube exposes captions as a load-time flag, not a live setting, so the
  /// player is recreated at the current timestamp with the other caption state.
  Future<void> _toggleCaptions() async {
    double position = 0;
    try {
      position = await _controller.currentTime;
    } catch (_) {
      // Keep zero: a position query can fail while the iframe is still loading.
    }
    unawaited(_values?.cancel());
    unawaited(_controller.close());
    if (!mounted) return;
    setState(() {
      _captionsEnabled = !_captionsEnabled;
      _attempt++;
    });
    _open(startSeconds: position, captions: _captionsEnabled);
  }

  @override
  void dispose() {
    unawaited(_values?.cancel());
    unawaited(_controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: YoutubePlayer(
              key: ValueKey<int>(_attempt),
              controller: _controller,
              aspectRatio: 16 / 9,
              backgroundColor: Colors.black,
              enableFullScreenOnVerticalDrag: false,
              autoFullScreen: false,
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTogglePause,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: ReelYoutubeControls(
            captionsEnabled: _captionsEnabled,
            onToggleCaptions: _toggleCaptions,
            onFullScreen: () => _controller.enterFullScreen(lock: false),
          ),
        ),
      ],
    );
  }
}

/// Captions and fullscreen controls for the native player.
///
/// Extracted so the interaction layer can be widget-tested without a platform
/// view: the icons, tooltips and enabled state are the part most likely to
/// regress, and they do not need a real iframe to verify.
class ReelYoutubeControls extends StatelessWidget {
  const ReelYoutubeControls({
    super.key,
    required this.captionsEnabled,
    required this.onToggleCaptions,
    required this.onFullScreen,
  });

  final bool captionsEnabled;
  final VoidCallback onToggleCaptions;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: captionsEnabled
                ? context.l10n.turnOffCaptions
                : context.l10n.turnOnCaptions,
            color: captionsEnabled ? Colors.white : Colors.white60,
            icon: const Icon(Icons.closed_caption),
            onPressed: onToggleCaptions,
          ),
          IconButton(
            tooltip: context.l10n.fullScreen,
            color: Colors.white,
            icon: const Icon(Icons.open_in_full),
            onPressed: onFullScreen,
          ),
        ],
      ),
    );
  }
}
