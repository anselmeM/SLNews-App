import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/url_normalizer.dart';

/// Remote image with a graceful, layout-stable placeholder.
///
/// Samsung-News-style cards always occupy their final size, so the placeholder
/// uses an identically sized neutral block with the publisher mark instead of a
/// spinner. A `null`/empty [url] is a normal state (RSS items frequently have
/// no image) and renders the same block deterministically.
class SlNetworkImage extends StatelessWidget {
  const SlNetworkImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderLabel,
    this.semanticLabel,
    this.alignment = Alignment.center,
    this.seed,
    this.fallbackIcon,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Short mark drawn on the fallback block, usually the outlet wordmark.
  final String? placeholderLabel;

  /// Description for screen readers; when null the image is decorative and
  /// excluded from the semantics tree (the surrounding tile names the story).
  final String? semanticLabel;

  final Alignment alignment;

  /// Stable text used to derive the fallback artwork colour, usually the
  /// article or publisher id, so the same story always gets the same card.
  final String? seed;

  /// Glyph shown when there is no image (category icon by default).
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final Widget image = _hasUrl
        ? _buildRemote(context)
        : _buildFallback(context);
    final Widget result = borderRadius == null
        ? image
        : ClipRRect(borderRadius: borderRadius!, child: image);
    final String? label = semanticLabel?.trim();
    if (label == null || label.isEmpty) {
      return ExcludeSemantics(child: result);
    }
    return Semantics(image: true, label: label, child: result);
  }

  String? get _secureUrl => UrlNormalizer.secureImage(url);

  bool get _hasUrl => _secureUrl != null;

  /// Optional server-side image proxy; bypasses hotlink protection, mixed
  /// content and dead direct URLs. Enabled per build, not required.
  static const String _proxyBase = String.fromEnvironment('SLNEWS_IMAGE_PROXY');

  /// Test-only image source.
  ///
  /// Widget tests cannot make network requests, so the store-capture harness
  /// substitutes local fixture photos here. Production leaves this null and
  /// every image goes through [CachedNetworkImage] as usual.
  @visibleForTesting
  static ImageProvider Function(String url)? debugImageProvider;

  Widget _buildRemote(BuildContext context) {
    final String url = _secureUrl!;
    final ImageProvider Function(String url)? override = debugImageProvider;
    if (override != null) {
      return Image(
        image: override(url),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) => _buildFallback(context),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      fadeInDuration: AppMotion.medium,
      placeholder: (BuildContext context, String url) =>
          _buildFallback(context),
      errorWidget: (BuildContext context, String url, Object error) =>
          _buildProxyOrFallback(context, url),
    );
  }

  Widget _buildProxyOrFallback(BuildContext context, String failedUrl) {
    if (_proxyBase.isEmpty) return _buildFallback(context);
    final String proxied = '$_proxyBase${Uri.encodeComponent(failedUrl)}';
    return CachedNetworkImage(
      imageUrl: proxied,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      fadeInDuration: AppMotion.medium,
      errorWidget: (BuildContext context, String url, Object error) =>
          _buildFallback(context),
    );
  }

  Widget _buildFallback(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String key = (seed ?? placeholderLabel ?? 'slnews').trim();
    final double hue = (key.hashCode.abs() % 360).toDouble();
    final HSLColor top = HSLColor.fromAHSL(
      1,
      hue,
      isDark ? 0.38 : 0.42,
      isDark ? 0.26 : 0.55,
    );
    final HSLColor bottom = HSLColor.fromAHSL(
      1,
      (hue + 26) % 360,
      isDark ? 0.42 : 0.5,
      isDark ? 0.14 : 0.36,
    );
    final IconData icon = fallbackIcon ?? Icons.newspaper;
    final double glyphSize = (math.min(width ?? 120, height ?? 120) * 0.30)
        .clamp(18, 64);
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[top.toColor(), bottom.toColor()],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Two translucent rings keep flat fallbacks from looking like a
          // loading state without introducing photography we do not own.
          Positioned(
            right: -18,
            top: -24,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x33FFFFFF), width: 10),
              ),
            ),
          ),
          Positioned(
            left: -26,
            bottom: -30,
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1FFFFFFF),
              ),
            ),
          ),
          Center(
            child: Icon(icon, size: glyphSize, color: const Color(0xE6FFFFFF)),
          ),
          if (placeholderLabel != null && placeholderLabel!.isNotEmpty)
            Positioned(
              left: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Text(
                placeholderLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.overline.copyWith(
                  color: const Color(0xCCFFFFFF),
                  letterSpacing: 0.8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
