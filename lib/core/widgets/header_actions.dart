import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_routes.dart';

/// Search and Saved shortcuts for a tab's app bar.
///
/// Both surfaces already existed but were reachable only from the kebab menu,
/// which meant readers never found them. They sit in the header of every tab so
/// the destination is one tap from anywhere.
class HeaderActions extends StatelessWidget {
  const HeaderActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search, size: 22),
          onPressed: () => context.push(AppRoutes.search),
        ),
        IconButton(
          tooltip: 'Saved stories',
          icon: const Icon(Icons.bookmark_outline, size: 22),
          onPressed: () => context.push(AppRoutes.saved),
        ),
      ],
    );
  }
}
