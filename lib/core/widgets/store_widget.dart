import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../domain/models/article.dart';

/// Android provider class that renders the home-screen widget.
const String androidWidgetProvider = 'SlNewsWidgetProvider';

String? _lastSignature;

/// Pushes the current headline to the home-screen widget.
///
/// Best-effort: the widget is a convenience, so a platform without `home_widget`
/// (tests, iOS) must never affect the feed. Repeat calls with the same content
/// are skipped so a rebuild does not hammer the launcher.
Future<void> syncStoreWidget({Article? top, required int breakingCount}) async {
  if (kIsWeb) return;
  final String signature = '${top?.id ?? ''}|$breakingCount';
  if (signature == _lastSignature) return;
  _lastSignature = signature;
  try {
    await HomeWidget.saveWidgetData<String>(
      'widget_title',
      top?.title ?? 'Top stories are loading',
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_meta',
      breakingCount > 0
          ? '$breakingCount breaking · Top stories'
          : 'Top stories',
    );
    await HomeWidget.saveWidgetData<String>('widget_article_id', top?.id ?? '');
    await HomeWidget.updateWidget(androidName: androidWidgetProvider);
  } catch (_) {
    // No widget host, or a platform where the plugin is absent.
  }
}
