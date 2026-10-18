import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Rounded white grouping card used by every settings group.
///
/// Mirrors the reference screen: one surface per group, an optional in-card
/// header, and divider-separated rows. Rows are spaced by the card itself so a
/// plain [List] of children keeps the dividers aligned to the text gutter.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, this.header, required this.children});

  /// Optional group title rendered as the card's first row (e.g. "Notifications").
  final String? header;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    if (header != null) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Text(header!, style: context.typography.groupTitle),
        ),
      );
    }
    for (int index = 0; index < children.length; index++) {
      rows.add(children[index]);
      if (index < children.length - 1) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: Divider(
              height: 1,
              thickness: 1,
              color: context.colors.divider,
            ),
          ),
        );
      }
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// Small grey label between cards ("News", "Appearance").
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        label,
        style: context.typography.meta.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Row with a title, an optional supporting line and a trailing switch.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: InkWell(
        // The whole row is the tap target, not just the 48dp switch thumb.
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: context.typography.body),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        style: context.typography.caption.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row with a title, an optional supporting line and a trailing value/chevron.
class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.valueColor,
    this.titleColor,
    this.onTap,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;

  /// Right-hand text, e.g. "English (Sierra Leone)".
  final String? value;
  final Color? valueColor;

  /// Overrides the title colour, e.g. the destructive "Delete account" row.
  final Color? titleColor;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: context.typography.body),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: context.typography.caption.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (value != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      value!,
                      style: context.typography.caption.copyWith(
                        color: valueColor ?? context.colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron)
              Icon(
                Icons.chevron_right,
                size: 22,
                color: context.colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
