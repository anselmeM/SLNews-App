import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/legal_links.dart';
import '../domain/models/ad_unit.dart';

/// Validates a sponsor landing page.
///
/// Only absolute HTTP(S) URLs with a host and no embedded credentials are
/// allowed. Ad payloads come from the network, so the app must not hand an
/// arbitrary scheme (`javascript:`, `intent:`, `file:`…) to the platform
/// launcher.
Uri? parseSponsorshipTarget(String? value) {
  final String raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  final Uri? uri = Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.userInfo.isNotEmpty) return null;
  return uri;
}

/// Opens a sponsor's landing page and answers whether it actually opened.
///
/// Callers use the result to decide whether a tap is billable. House units with
/// no target keep the old explanatory snackbar, but are never counted.
Future<bool> openSponsorship(
  BuildContext context,
  WidgetRef ref,
  AdUnit unit,
) async {
  final Uri? target = parseSponsorshipTarget(unit.targetUrl);
  if (target == null) {
    if (context.mounted) {
      _showSnack(
        context,
        unit.isSold
            ? 'This sponsor link is unavailable.'
            : '${unit.advertiser}: ${unit.ctaLabel}',
      );
    }
    return false;
  }

  bool opened = false;
  try {
    opened = await ref.read(externalUrlOpenerProvider)(target.toString());
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    _showSnack(context, 'Could not open the sponsor link');
  }
  return opened;
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
}
