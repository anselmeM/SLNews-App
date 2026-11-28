import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Shared chrome for the "Manage ..." catalogue screens.
///
/// The five catalogue pages previously repeated the same scaffold, back button,
/// subtitle, search field and expanded body. Keeping the layout here means the
/// back affordance, padding and search treatment cannot drift per page.
class CataloguePageScaffold extends StatelessWidget {
  const CataloguePageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.searchHint,
    this.onQueryChanged,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// When both are set, a search field is rendered above [child].
  final String? searchHint;
  final ValueChanged<String>? onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: Text(title, style: context.typography.groupTitle),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Text(subtitle, style: context.typography.caption),
          ),
          if (searchHint != null && onQueryChanged != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: TextField(
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: searchHint,
                ),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
