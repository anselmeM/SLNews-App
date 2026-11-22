import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_language.dart';
import '../../../../core/config/l10n.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Opens the language sheet and applies the chosen language.
Future<void> pickAppLanguage(BuildContext context, WidgetRef ref) async {
  final AppLanguage current = ref
      .read(localeControllerProvider.notifier)
      .selected;
  final AppLanguage? choice = await showModalBottomSheet<AppLanguage>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.languageAndRegion,
                style: context.typography.groupTitle,
              ),
            ),
            for (final AppLanguage language in AppLanguage.values)
              ListTile(
                enabled: language.hasTranslation,
                leading: Icon(
                  language == current
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: language.hasTranslation
                      ? context.colors.live
                      : context.colors.onSurfaceFaint,
                ),
                title: Text(language.endonym),
                subtitle: language.hasTranslation
                    ? null
                    : Text(l10n.languageKrioNote),
                onTap: language.hasTranslation
                    ? () => Navigator.of(sheetContext).pop(language)
                    : null,
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;
  await ref.read(localeControllerProvider.notifier).setLanguage(choice);
}
