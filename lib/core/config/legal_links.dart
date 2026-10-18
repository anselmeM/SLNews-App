import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public legal URLs shown in Settings.
///
/// The custom domain (`slnews.sl`) is not registered yet, so these point at the
/// live deployment. When the domain is live, change the three constants and the
/// Play listing URLs in the same pass.
abstract final class LegalLinks {
  static const String privacy = 'https://sl-news.vercel.app/privacy';
  static const String terms = 'https://sl-news.vercel.app/terms';

  /// The public deletion page (works without the app installed).
  static const String deleteAccount =
      'https://sl-news.vercel.app/delete-account';
}

/// Opens a URL outside the app.
///
/// A provider rather than a direct `launchUrl` call so widget tests can record
/// taps instead of tripping over the platform channel.
final Provider<Future<bool> Function(String url)> externalUrlOpenerProvider =
    Provider<Future<bool> Function(String url)>(
      (Ref ref) => (String url) async {
        try {
          return await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        } catch (error) {
          return false;
        }
      },
      name: 'externalUrlOpener',
    );
