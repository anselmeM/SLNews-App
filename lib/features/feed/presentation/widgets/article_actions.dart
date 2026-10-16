import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/providers/controllers.dart';
import '../../../../core/widgets/overflow_menu_button.dart';

/// Runs one [ArticleAction] for [article] and always leaves the reader with
/// feedback.
///
/// Every platform call (share sheet, URL launch) is best-effort: a device
/// without a share target or browser shows a SnackBar instead of surfacing an
/// unhandled exception. Bookmarking is the only state change and it is applied
/// through [bookmarksControllerProvider] so the whole app stays in sync.
Future<void> handleArticleAction(
  BuildContext context,
  WidgetRef ref,
  Article article,
  ArticleAction action,
) async {
  // Captured before the first `await` so the SnackBar still works when the
  // originating tile has been disposed by a rebuild.
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  switch (action) {
    case ArticleAction.bookmark:
    case ArticleAction.removeBookmark:
      unawaited(_runBookmark(ref, article, action, messenger));
    case ArticleAction.share:
      await _share(article, messenger);
    case ArticleAction.openInBrowser:
      await _openInBrowser(article, messenger);
    case ArticleAction.hide:
      _showMessage(messenger, 'Story hidden from your feed');
    case ArticleAction.report:
      _showMessage(messenger, "Thanks — we'll review this story");
    case ArticleAction.followPublisher:
      _showMessage(messenger, 'Following ${article.publisher.name}');
  }
}

Future<void> _runBookmark(
  WidgetRef ref,
  Article article,
  ArticleAction action,
  ScaffoldMessengerState messenger,
) async {
  // A storage failure must not become an unhandled async error; the reader
  // simply keeps the previous state.
  try {
    await _toggleBookmark(ref, article, action);
  } on Object {
    _showMessage(messenger, "Couldn't update your saved stories");
    return;
  }
  _showMessage(
    messenger,
    action == ArticleAction.bookmark
        ? 'Saved for offline reading'
        : 'Removed from saved',
  );
}

Future<void> _toggleBookmark(
  WidgetRef ref,
  Article article,
  ArticleAction action,
) async {
  final BookmarksController controller = ref.read(
    bookmarksControllerProvider.notifier,
  );
  final bool currentlySaved = controller.isBookmarked(article.id);
  // Honours the explicit action so "Remove from saved" always removes, even if
  // another screen changed the state between build and tap.
  if (action == ArticleAction.bookmark && currentlySaved) return;
  if (action == ArticleAction.removeBookmark && !currentlySaved) return;
  await controller.toggle(article.id);
}

Future<void> _share(Article article, ScaffoldMessengerState messenger) async {
  final String? url = article.sourceUrl;
  final String text = (url == null || url.isEmpty)
      ? article.title
      : '${article.title}\n$url';
  try {
    await SharePlus.instance.share(ShareParams(text: text));
  } on Object {
    _showMessage(messenger, "Couldn't open the share sheet");
  }
}

Future<void> _openInBrowser(
  Article article,
  ScaffoldMessengerState messenger,
) async {
  final String? url = article.sourceUrl;
  if (url == null || url.isEmpty) {
    _showMessage(messenger, 'No link available for this story');
    return;
  }
  try {
    final bool launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) _showMessage(messenger, "Couldn't open this story");
  } on Object {
    _showMessage(messenger, "Couldn't open this story");
  }
}

void _showMessage(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
