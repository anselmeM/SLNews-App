/// Rules for the "Read original" mode: the in-app page that loads the
/// publisher's own article, with the SLNews reader chrome painted over it.
///
/// Kept free of Flutter so the decisions can be tested directly: which links stay
/// inside the page, which leave the app, and what typography is injected.
library;

/// How a link tapped inside the publisher page is handled.
enum ArticleLinkAction {
  /// Navigate inside the in-app page (same publisher, or an in-page anchor).
  allowInPage,

  /// Hand off to the platform browser/app (another domain, `mailto:`, `tel:`…).
  openExternally,

  /// Never execute, e.g. `javascript:` links or an Android `intent:` URI.
  block,
}

/// What the “Read original” header action should do.
enum ArticleOriginalAction {
  /// HTTPS publisher page: render it in the in-app WebView.
  inApp,

  /// HTTP publisher page: hand off to the platform browser rather than loading
  /// unencrypted content inside the app.
  external,

  /// No absolute web URL.
  none,
}

abstract final class ArticleWebMode {
  /// Schemes that must never reach the platform launcher.
  ///
  /// `javascript:`, `data:` and `blob:` would execute in our own WebView.
  /// `intent:` and `android-app:` are the dangerous ones for a publisher page:
  /// a tapped link can construct an arbitrary Android intent (component,
  /// extras, flags) and hand it to the OS, which is a classic cross-app
  /// escalation path. `file:`/`content:` would probe local storage, and
  /// `vbscript:` is legacy IE.
  static const Set<String> _blockedSchemes = <String>{
    'javascript',
    'data',
    'blob',
    'file',
    'content',
    'intent',
    'android-app',
    'vbscript',
  };

  /// Decides what happens to [target] tapped while reading [article].
  ///
  /// Same host and its subdomains stay in the page, because that is still the
  /// same publisher and leaving the app there would be jarring. Anything else —
  /// another outlet, a shop, a mail link — belongs to the platform, not to us.
  static ArticleLinkAction linkAction({
    required Uri target,
    required Uri article,
  }) {
    final String scheme = target.scheme.toLowerCase();
    if (_blockedSchemes.contains(scheme)) return ArticleLinkAction.block;
    if (scheme.isEmpty) return ArticleLinkAction.allowInPage;
    if (scheme != 'http' && scheme != 'https') {
      return ArticleLinkAction.openExternally;
    }

    final String articleHost = article.host.toLowerCase();
    final String targetHost = target.host.toLowerCase();
    if (articleHost.isEmpty) return ArticleLinkAction.openExternally;
    if (targetHost == articleHost) return ArticleLinkAction.allowInPage;
    // `news.bbc.co.uk` and `bbc.co.uk` are the same publisher even though only
    // one is a subdomain of the other.
    if (targetHost.endsWith('.$articleHost') ||
        articleHost.endsWith('.$targetHost')) {
      return ArticleLinkAction.allowInPage;
    }
    return ArticleLinkAction.openExternally;
  }

  /// Decides how the “Read original” action opens [sourceUrl].
  static ArticleOriginalAction originalAction(String? sourceUrl) {
    final Uri? uri = Uri.tryParse(sourceUrl?.trim() ?? '');
    if (uri == null || !uri.hasAbsolutePath) {
      return ArticleOriginalAction.none;
    }
    return switch (uri.scheme.toLowerCase()) {
      'https' => ArticleOriginalAction.inApp,
      'http' => ArticleOriginalAction.external,
      _ => ArticleOriginalAction.none,
    };
  }

  /// True when the story can be shown as the publisher's page at all.
  ///
  /// HTTPS only: cleartext pages are opened in the platform browser so the app
  /// never renders unencrypted publisher content in an in-app WebView.
  static bool canReadOriginal(String? sourceUrl) =>
      originalAction(sourceUrl) == ArticleOriginalAction.inApp;

  /// JavaScript injected after every load (and again when the reader changes the
  /// text size).
  ///
  /// It sets the root font size so relative page typography follows the app's
  /// `aA` setting (the mechanism the reference app demonstrates), constrains
  /// media to the viewport, and reports scroll progress back through the
  /// `SlnewsProgress` JavaScript channel.
  static String typographyScript({
    required double textScale,
    required bool dark,
  }) {
    final double boundedScale = textScale.clamp(0.8, 2.0);
    final int baseFontSize = (16 * boundedScale).round();
    final String colorScheme = dark ? '"dark"' : '"light"';
    return <String>[
      '(function(){',
      'var h=document.documentElement;',
      'h.style.setProperty("-webkit-text-size-adjust","none","important");',
      'h.style.fontSize="${baseFontSize}px";',
      'h.style.colorScheme=$colorScheme;',
      'var s=document.getElementById("slnews-reader-style");',
      'if(!s){s=document.createElement("style");s.id="slnews-reader-style";',
      '(document.head||document.documentElement).appendChild(s);}',
      's.textContent="figure,img,iframe,video,picture{max-width:100%!important;height:auto!important}";',
      'if(!window.__slnewsProgress){window.__slnewsProgress=true;',
      'window.addEventListener("scroll",function(){',
      'var d=h.scrollHeight-h.clientHeight;',
      'var p=d>0?h.scrollTop/d:0;',
      'if(window.SlnewsProgress){',
      'window.SlnewsProgress.postMessage(String(Math.min(1,Math.max(0,p))));}',
      '},{passive:true});}',
      '})();',
    ].join();
  }
}
