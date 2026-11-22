import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sources/sponsorship_tracker.dart';
import '../domain/models/ad_unit.dart';
import '../providers/app_providers.dart';
import 'ad_card.dart';

/// [AdCard] plus measurement.
///
/// An impression is recorded only after at least half of the card has been on
/// screen for one second. A tap is recorded only when the caller's open callback
/// reports that a real landing page opened; a missing, invalid or unreachable
/// target is never billable.
class TrackedAdCard extends ConsumerStatefulWidget {
  const TrackedAdCard({
    super.key,
    required this.unit,
    this.onCtaPressed,
    this.onOpened,
  });

  final AdUnit unit;

  /// Opens the sponsor target for the CTA button and reports whether it opened.
  final Future<bool> Function()? onCtaPressed;

  /// Opens the sponsor target for a card tap and reports whether it opened.
  final Future<bool> Function(AdUnit unit)? onOpened;

  @override
  ConsumerState<TrackedAdCard> createState() => _TrackedAdCardState();
}

class _TrackedAdCardState extends ConsumerState<TrackedAdCard> {
  static const int _visiblePollsRequired = 4;
  static const Duration _poll = Duration(milliseconds: 300);

  Timer? _visibilityTimer;
  int _visiblePolls = 0;
  bool _impressionCounted = false;

  @override
  void initState() {
    super.initState();
    _visibilityTimer = Timer.periodic(_poll, (_) => _pollVisibility());
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    super.dispose();
  }

  SponsorshipTracker? _tracker() {
    try {
      return ref.read(sponsorshipTrackerProvider);
    } catch (_) {
      return null;
    }
  }

  void _pollVisibility() {
    if (!mounted || _impressionCounted) {
      _visibilityTimer?.cancel();
      return;
    }
    if (!_isAtLeastHalfVisible()) {
      _visiblePolls = 0;
      return;
    }
    _visiblePolls += 1;
    if (_visiblePolls < _visiblePollsRequired) return;
    _impressionCounted = true;
    _visibilityTimer?.cancel();
    _tracker()?.impression(widget.unit);
  }

  bool _isAtLeastHalfVisible() {
    final RenderObject? render = context.findRenderObject();
    if (render is! RenderBox || !render.hasSize || !render.attached) {
      return false;
    }
    final Size screen = MediaQuery.sizeOf(context);
    final Offset origin = render.localToGlobal(Offset.zero);
    final Rect card = origin & render.size;
    final Rect viewport = Offset.zero & screen;
    final Rect overlap = card.intersect(viewport);
    if (overlap.width <= 0 || overlap.height <= 0) return false;
    return (overlap.width * overlap.height) >= (card.width * card.height) * 0.5;
  }

  Future<void> _opened(AdUnit unit) async {
    final bool opened = await (widget.onOpened?.call(unit) ?? false);
    if (opened) _tracker()?.tap(unit);
  }

  Future<void> _cta() async {
    final bool opened = await (widget.onCtaPressed?.call() ?? false);
    if (opened) _tracker()?.tap(widget.unit);
  }

  @override
  Widget build(BuildContext context) {
    return AdCard(
      unit: widget.unit,
      onCtaPressed: widget.onCtaPressed == null
          ? null
          : () => unawaited(_cta()),
      onOpened: widget.onOpened == null
          ? null
          : (AdUnit unit) => unawaited(_opened(unit)),
    );
  }
}
