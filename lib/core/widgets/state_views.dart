import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/time_ago.dart';

/// Full-page error with a retry affordance.
///
/// Copy is deliberately plain and non-technical; the diagnostic detail belongs
/// in logs, not in front of a reader on a 2G connection.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    this.message = "We couldn't load this right now.",
    this.onRetry,
    this.icon = Icons.cloud_off_outlined,
  });

  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: context.colors.onSurfaceFaint),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.typography.body,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state for bookmarks, search and filtered streams.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.bookmark_border,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 40, color: context.colors.onSurfaceFaint),
            const SizedBox(height: AppSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: context.typography.groupTitle),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(message!, textAlign: TextAlign.center, style: context.typography.caption),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Slim banner telling the reader they are seeing cached content.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.isOffline,
    this.message = 'Offline — showing saved stories',
    this.lastSyncedAt,
  });

  final bool isOffline;
  final String message;
  final DateTime? lastSyncedAt;

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();
    final String detail = lastSyncedAt == null ? message : '$message · updated ${lastSyncedAt!.relativeLabel}';
    return Container(
      width: double.infinity,
      color: context.colors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Icon(Icons.wifi_off_outlined, size: 15, color: context.colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.meta,
            ),
          ),
        ],
      ),
    );
  }
}
