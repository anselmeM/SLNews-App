import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sources/sponsorship_tracker.dart';
import '../domain/models/ad_unit.dart';
import '../providers/app_providers.dart';
import 'ad_card.dart';

/// [AdCard] plus measurement: one impression when it is first built, one tap when
/// the creative is opened. Only directly sold units are counted.
class TrackedAdCard extends ConsumerStatefulWidget {
  const TrackedAdCard({
    super.key,
    required this.unit,
    this.onCtaPressed,
    this.onOpened,
  });

  final AdUnit unit;
  final VoidCallback? onCtaPressed;
  final ValueChanged<AdUnit>? onOpened;

  @override
  ConsumerState<TrackedAdCard> createState() => _TrackedAdCardState();
}

class _TrackedAdCardState extends ConsumerState<TrackedAdCard> {
  @override
  void initState() {
    super.initState();
    _tracker()?.impression(widget.unit);
  }

  SponsorshipTracker? _tracker() {
    try {
      return ref.read(sponsorshipTrackerProvider);
    } catch (_) {
      return null;
    }
  }

  void _opened(AdUnit unit) {
    _tracker()?.tap(unit);
    widget.onOpened?.call(unit);
  }

  void _cta() {
    _tracker()?.tap(widget.unit);
    widget.onCtaPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AdCard(
      unit: widget.unit,
      onCtaPressed: _cta,
      onOpened: widget.onOpened == null ? null : _opened,
    );
  }
}
