part of 'settings_page.dart';

Future<void> _showChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required Map<T, String> options,
  required T selected,
  required Future<void> Function(T value) onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (BuildContext sheetContext) {
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
              child: Text(title, style: sheetContext.typography.groupTitle),
            ),
            for (final MapEntry<T, String> option in options.entries)
              ListTile(
                title: Text(option.value, style: sheetContext.typography.body),
                trailing: option.key == selected
                    ? Icon(
                        Icons.check,
                        color: sheetContext.colors.primary,
                        size: 20,
                      )
                    : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onSelected(option.key);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );
}

Future<void> _showPersonalizationData(
  BuildContext context,
  PersonalizationProfile profile,
  WidgetRef ref,
) async {
  final bool? reset = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: const Text('Personalization data'),
      content: Text(
        profile.isEmpty
            ? 'No personalization signals are stored on this device.'
            : '${profile.eventCount} local signals and '
                  '${profile.unfinishedCount} unfinished reading positions '
                  'are stored only on this device. They are never sent to '
                  'SLNews servers.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Close'),
        ),
        if (!profile.isEmpty)
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
      ],
    ),
  );
  if (reset != true || !context.mounted) return;
  final bool cleared = await ref
      .read(personalizationProfileProvider.notifier)
      .clear();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          cleared
              ? 'Personalization data was reset'
              : "Couldn't reset personalization data. Please try again.",
        ),
      ),
    );
}
