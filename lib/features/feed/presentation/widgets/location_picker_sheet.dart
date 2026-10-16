import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/models/follow_models.dart';
import '../../../../core/providers/controllers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_glyphs.dart';

/// Opens the compact location switcher used by the For You weather chip.
///
/// The sheet is intentionally a plain list: switching the home city is a
/// two-tap action and the selected row is the only state it renders.
Future<void> openLocationPicker(BuildContext context, WidgetRef ref) {
  final String selectedId = ref
      .read(settingsControllerProvider)
      .activeLocationId;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (BuildContext sheetContext) =>
        _LocationPickerSheet(selectedId: selectedId),
  );
}

class _LocationPickerSheet extends ConsumerWidget {
  const _LocationPickerSheet({required this.selectedId});

  final String selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text('Your location', style: context.typography.groupTitle),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: SlLocations.all.length,
              itemBuilder: (BuildContext context, int index) {
                final NewsLocation location = SlLocations.all[index];
                final bool isSelected = location.id == selectedId;
                return ListTile(
                  leading: Icon(
                    AppGlyphs.follow(FollowKind.location),
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.onSurfaceVariant,
                  ),
                  title: Text(
                    location.label,
                    style: isSelected
                        ? context.typography.cardTitleSmall.copyWith(
                            color: context.colors.primary,
                          )
                        : context.typography.cardTitleSmall,
                  ),
                  subtitle: Text(
                    location.subtitle,
                    style: context.typography.caption,
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check,
                          size: 20,
                          color: context.colors.primary,
                        )
                      : null,
                  onTap: () {
                    // Switch the home city, then close; the page rebuilds from
                    // the settings controller, so no local state is needed.
                    ref
                        .read(settingsControllerProvider.notifier)
                        .setActiveLocation(location.id);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
