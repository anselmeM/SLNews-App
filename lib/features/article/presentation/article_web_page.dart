import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  /// Created lazily while the page can actually load: a widget test (or an
  /// offline device) never instantiates the platform WebView.
  WebViewController? _controller;
  double _progress = 0;
  bool _loading = true;
  bool _failed = false;

  /// Incremented on retry so a fresh controller and page load start over.
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

    final WebViewController? controller = showWeb
        ? (_controller ??= _createController())
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final WebViewController? web = _controller;
        if (web != null && await web.canGoBack()) {
          await web.goBack();
          return;
        }
        _pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            if (controller != null)
              Positioned.fill(
                key: ValueKey<int>(_attempt),
                child: WebViewWidget(controller: controller),
              ),
            if (!showWeb)
              Positioned.fill(
                child: _Fallback(
                  article: _article,
                  offline: offline.isOffline,
                  missingLink: !hasSource,
                  onReadHere: _pop,
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
                  onReadHere: _pop,
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

  WebViewController _createController() {
    final String sourceUrl = _article.sourceUrl!;
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        _progressChannel,
        onMessageReceived: _onProgressMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (!mounted) return;
            setState(() => _loading = progress < 100);
          },
          onPageFinished: (String _) async {
            await _applyTypography();
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: _onWebResourceError,
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(sourceUrl));
  }

  void _onProgressMessage(JavaScriptMessage message) {
    final double value = (double.tryParse(message.message) ?? 0).clamp(0, 1);
    if (mounted && (value - _progress).abs() > 0.004) {
      setState(() => _progress = value);
    }
  }

  Future<void> _applyTypography() async {
    final WebViewController? controller = _controller;
    if (controller == null) return;
    final double scale = ref.read(settingsControllerProvider).textScale;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    try {
      await controller.runJavaScript(
        ArticleWebMode.typographyScript(textScale: scale, dark: dark),
      );
    } catch (error) {
      reportError(error, where: 'article-webview-typography');
    }
  }

  void _onWebResourceError(WebResourceError error) {
    if (error.isForMainFrame == false) return;
    reportError(
      StateError('Original page failed: ${error.description}'),
      where: 'article-webview',
    );
    if (mounted) setState(() => _failed = true);
  }

  Future<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) async {
    final Uri? articleUri = Uri.tryParse(_article.sourceUrl ?? '');
    final Uri? target = Uri.tryParse(request.url);
    if (articleUri == null || target == null) {
      return NavigationDecision.prevent;
    }

    switch (ArticleWebMode.linkAction(target: target, article: articleUri)) {
      case ArticleLinkAction.allowInPage:
        return NavigationDecision.navigate;
      case ArticleLinkAction.block:
        return NavigationDecision.prevent;
      case ArticleLinkAction.openExternally:
        try {
          await launchUrl(target, mode: LaunchMode.externalApplication);
        } catch (error) {
          reportError(error, where: 'article-webview-link');
        }
        return NavigationDecision.prevent;
    }
  }

  Future<void> _onBack() async {
    final WebViewController? controller = _controller;
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
      _controller = null;
      _failed = false;
      _loading = true;
      _progress = 0;
      _attempt++;
    });
  }

  static const String _progressChannel = 'SlnewsProgress';
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
