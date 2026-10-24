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

  Widget _buildRemote(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _secureUrl!,
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
    final Color base = context.colors.skeleton;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            base,
            Color.lerp(base, isDark ? Colors.black : Colors.white, 0.35) ??
                base,
          ],
        ),
      ),
      child: placeholderLabel == null || placeholderLabel!.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                placeholderLabel!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.overline.copyWith(
                  color: context.colors.onSurfaceFaint,
                ),
              ),
            ),
    );
  }
}
