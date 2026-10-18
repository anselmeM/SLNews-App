import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/article.dart';
import '../../../core/observability/error_reporter.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/providers/offline_status.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/publisher_mark.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/article_web_mode.dart';
import 'widgets/article_action_bar.dart';
import 'widgets/reading_progress_bar.dart';

/// "Read original" mode (`/article/:id/original`).
///
/// Loads the publisher's own article full screen and keeps SLNews' reader chrome
/// over it: back, the outlet wordmark, a route back to the native reader, the
/// reading-progress hairline and the floating action bar. The native reader stays
/// the offline and fallback path; this page only exists when a published link
/// does and the network is available.
class ArticleWebPage extends ConsumerWidget {
  const ArticleWebPage({super.key, required this.articleId});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Article?> article = ref.watch(articleProvider(articleId));

    return article.when(
      loading: () => const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
      error: (Object error, StackTrace stackTrace) => Scaffold(
        body: SafeArea(
          child: ErrorStateView(
            message: "We couldn't open this story.",
            onRetry: () => ref.invalidate(articleProvider(articleId)),
          ),
        ),
      ),
      data: (Article? story) {
        if (story == null) {
          return Scaffold(
            body: SafeArea(
              child: EmptyStateView(
                title: 'Story unavailable',
                message: 'This story is no longer in your saved feed.',
                actionLabel: 'Back',
                onAction: () => context.pop(),
                icon: Icons.article_outlined,
              ),
            ),
          );
        }
        return _WebReader(article: story);
      },
    );
  }
}

class _WebReader extends ConsumerStatefulWidget {
  const _WebReader({required this.article});

  final Article article;

  @override
  ConsumerState<_WebReader> createState() => _WebReaderState();
}

class _WebReaderState extends ConsumerState<_WebReader> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _loading = true;
  bool _failed = false;

  /// Incremented on retry so the WebView is recreated from scratch.
  int _attempt = 0;

  Article get _article => widget.article;

  @override
  Widget build(BuildContext context) {
    final OfflineStatus offline = readOfflineStatus(ref);
    final bool hasSource = ArticleWebMode.canReadOriginal(_article.sourceUrl);
    final bool showWeb = hasSource && !offline.isOffline && !_failed;

    // Re-inject typography whenever the reader cycles the text size, so `aA`
    // works here exactly as it does in the native reader.
    ref.listen<double>(
      settingsControllerProvider.select(
        (AppSettings settings) => settings.textScale,
      ),
      (double? previous, double next) => _applyTypography(),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final InAppWebViewController? controller = _controller;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
        _pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            if (showWeb)
              Positioned.fill(
                child: KeyedSubtree(
                  key: ValueKey<int>(_attempt),
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri(_article.sourceUrl!),
                    ),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      // Publisher pages run their own trackers; keep no
                      // persistent cookies or cache for them.
                      incognito: true,
                      transparentBackground: true,
                      allowFileAccess: false,
                      allowContentAccess: false,
                      supportZoom: false,
                      mediaPlaybackRequiresUserGesture: true,
                      allowsBackForwardNavigationGestures: true,
                      useShouldOverrideUrlLoading: true,
                    ),
                    onWebViewCreated: _onWebViewCreated,
                    onLoadStop: _onLoadStop,
                    onProgressChanged: (_, int progress) {
                      if (!mounted) return;
                      setState(() => _loading = progress < 100);
                    },
                    onReceivedError: _onReceivedError,
                    onReceivedHttpError: _onReceivedHttpError,
                    shouldOverrideUrlLoading: _onNavigate,
                  ),
                ),
              ),
            if (!showWeb)
              Positioned.fill(
                child: _Fallback(
                  article: _article,
                  offline: offline.isOffline,
                  missingLink: !hasSource,
                  onReadHere: () => context.pop(),
                  onRetry: _retry,
                ),
              ),
            const Positioned(top: 0, left: 0, right: 0, child: _TopScrim()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _TopBar(
                  article: _article,
                  canGoBack: showWeb,
                  onBack: _onBack,
                  onReadHere: () => context.pop(),
                  onReload: _retry,
                ),
              ),
            ),
            if (showWeb && _loading)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 52,
                left: 0,
                right: 0,
                child: const LinearProgressIndicator(minHeight: 2),
              ),
            if (showWeb && !_loading)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 52,
                left: 0,
                right: 0,
                child: ReadingProgressBar(progress: _progress),
              ),
          ],
        ),
        bottomNavigationBar: ArticleActionBar(article: _article),
      ),
    );
  }

  Future<void> _onWebViewCreated(InAppWebViewController controller) async {
    _controller = controller;
    controller.addJavaScriptHandler(
      handlerName: 'readingProgress',
      callback: (List<dynamic> args) {
        final double value = args.isEmpty
            ? 0
            : (args.first as num).toDouble().clamp(0.0, 1.0);
        if (mounted && (value - _progress).abs() > 0.004) {
          setState(() => _progress = value);
        }
        return null;
      },
    );
  }

  Future<void> _onLoadStop(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    await _applyTypography();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _applyTypography() async {
    final InAppWebViewController? controller = _controller;
    if (controller == null) return;
    final double scale = ref.read(settingsControllerProvider).textScale;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    try {
      await controller.evaluateJavascript(
        source: ArticleWebMode.typographyScript(textScale: scale, dark: dark),
      );
    } catch (error) {
      reportError(error, where: 'article-webview-typography');
    }
  }

  void _onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    if (request.isForMainFrame != true) return;
    reportError(
      StateError('Original page failed: ${error.description}'),
      where: 'article-webview',
    );
    if (mounted) setState(() => _failed = true);
  }

  void _onReceivedHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse response,
  ) {
    if (request.isForMainFrame != true) return;
    if ((response.statusCode ?? 0) < 400) return;
    reportError(
      StateError('Original page answered HTTP ${response.statusCode}'),
      where: 'article-webview',
    );
    if (mounted) setState(() => _failed = true);
  }

  Future<NavigationActionPolicy> _onNavigate(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final Uri? articleUri = Uri.tryParse(_article.sourceUrl ?? '');
    final WebUri? target = action.request.url;
    if (articleUri == null || target == null) {
      return NavigationActionPolicy.CANCEL;
    }

    final Uri uri = Uri.parse(target.toString());
    switch (ArticleWebMode.linkAction(target: uri, article: articleUri)) {
      case ArticleLinkAction.allowInPage:
        return NavigationActionPolicy.ALLOW;
      case ArticleLinkAction.block:
        return NavigationActionPolicy.CANCEL;
      case ArticleLinkAction.openExternally:
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (error) {
          reportError(error, where: 'article-webview-link');
        }
        return NavigationActionPolicy.CANCEL;
    }
  }

  Future<void> _onBack() async {
    final InAppWebViewController? controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    _pop();
  }

  void _pop() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _failed = false;
      _loading = true;
      _progress = 0;
      _attempt++;
    });
  }
}

/// Dark gradient behind the top bar so white controls stay legible over any page.
class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: SizedBox(
        height: 132,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xCC000000), Color(0x00000000)],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.article,
    required this.canGoBack,
    required this.onBack,
    required this.onReadHere,
    required this.onReload,
  });

  final Article article;
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onReadHere;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            _OverlayButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onTap: onBack,
            ),
            Expanded(
              child: Center(
                child: PublisherMark(
                  publisher: article.publisher,
                  logoHeight: 18,
                  maxWidth: 140,
                  color: Colors.white,
                ),
              ),
            ),
            if (canGoBack)
              _OverlayButton(
                icon: Icons.refresh,
                tooltip: 'Reload original',
                onTap: onReload,
              ),
            const SizedBox(width: AppSpacing.xs),
            _OverlayButton(
              label: 'Reader',
              tooltip: 'Read in the SLNews reader',
              onTap: onReadHere,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    this.icon,
    this.label,
    required this.tooltip,
    required this.onTap,
  }) : assert(icon != null || label != null, 'icon or label required');

  final IconData? icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: icon == null ? AppSpacing.md : AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: icon != null
                ? Icon(icon, size: 20, color: Colors.white)
                : Text(
                    label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Explains why the publisher page cannot be shown and offers the native reader.
class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.article,
    required this.offline,
    required this.missingLink,
    required this.onReadHere,
    required this.onRetry,
  });

  final Article article;
  final bool offline;
  final bool missingLink;
  final VoidCallback onReadHere;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String title = missingLink
        ? 'No original page'
        : offline
        ? "You're offline"
        : "The original page didn't open";
    final String message = missingLink
        ? 'This story has no published link. Read it in the SLNews reader instead.'
        : offline
        ? 'The original page needs a connection. The SLNews version stays available offline.'
        : '${article.publisher.name} may block in-app browsers. Read the SLNews version instead.';

    return ColoredBox(
      color: context.colors.canvas,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  missingLink
                      ? Icons.link_off
                      : offline
                      ? Icons.cloud_off
                      : Icons.language,
                  size: 40,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.typography.groupTitle,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.typography.body.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: onReadHere,
                  child: const Text('Read in SLNews reader'),
                ),
                if (!missingLink) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
