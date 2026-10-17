import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/domain/models/article.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Languages the reader's translate action offers.
///
/// The list is deliberately short and explicit rather than a full locale
/// catalogue: each entry has to be a code Google Translate accepts, and an
/// unsupported code fails silently there.
enum TranslateLanguage {
  french('fr', 'French'),
  portuguese('pt', 'Portuguese'),
  arabic('ar', 'Arabic'),
  spanish('es', 'Spanish'),
  chinese('zh-CN', 'Chinese (Simplified)');

  const TranslateLanguage(this.code, this.label);

  final String code;
  final String label;
}

/// The Google Translate URL for [article] in [language].
///
/// `null` when the story has no original link: translating a story we cannot
/// address is not possible, and the caller says so instead of opening a
/// translator on nothing.
@visibleForTesting
Uri? translationUriFor(Article article, TranslateLanguage language) {
  final String? link = article.sourceUrl?.trim();
  if (link == null || link.isEmpty) return null;
  return Uri.parse('https://translate.google.com/translate').replace(
    queryParameters: <String, String>{
      'sl': 'auto',
      'tl': language.code,
      'u': link,
    },
  );
}

/// Opens the translation flow for [article].
///
/// The reader picks a language, then the story opens in Google Translate's web
/// translator. Nothing is translated on-device: the app has no translation model
/// and shipping one would dwarf the app, so the action hands the original link to
/// a service the reader already trusts — which is also why it needs
/// [Article.sourceUrl].
Future<void> openTranslation(BuildContext context, Article article) async {
  final TranslateLanguage?
  language = await showModalBottomSheet<TranslateLanguage>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (BuildContext sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Text(
              'Translate story',
              style: sheetContext.typography.groupTitle,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(
              'Opens the original story in Google Translate.',
              style: sheetContext.typography.caption.copyWith(
                color: sheetContext.colors.onSurfaceVariant,
              ),
            ),
          ),
          for (final TranslateLanguage option in TranslateLanguage.values)
            ListTile(
              leading: Icon(
                Icons.translate,
                size: 20,
                color: sheetContext.colors.onSurfaceVariant,
              ),
              title: Text(option.label, style: sheetContext.typography.body),
              onTap: () => Navigator.of(sheetContext).pop(option),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );

  if (language == null || !context.mounted) return;

  final Uri? target = translationUriFor(article, language);
  if (target == null) {
    _snack(context, 'Translation needs the original story link');
    return;
  }

  final bool opened = await launchUrl(
    target,
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    _snack(context, 'Could not open the translation');
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
