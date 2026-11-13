import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/models/app_settings.dart';
import '../../../core/domain/models/follow_models.dart';
import '../../../core/providers/controllers.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// First-run personalisation: pick a few topics and a home city before the
/// first For You render. This is the write side of the Following loop —
/// selections become `following.ids` and the feed ranks them immediately.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final Set<String> _topics = <String>{};
  String? _locationId;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final FollowingSnapshot snapshot = ref.watch(followingControllerProvider);
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final List<FollowTarget> topics = snapshot.topics
        .where((FollowTarget target) => target.kind == FollowKind.topic)
        .toList(growable: false);
    final String locationId = _locationId ?? settings.activeLocationId;

    return Scaffold(
      backgroundColor: context.colors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  _Header(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.xxl,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Topics you care about',
                          style: context.typography.groupTitle,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'These shape your For You feed, alerts and Following tab.',
                          style: context.typography.caption,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (topics.isEmpty)
                          Text(
                            'You can add topics later from Following.',
                            style: context.typography.caption,
                          )
                        else
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              for (final FollowTarget topic in topics)
                                FilterChip(
                                  label: Text(topic.label),
                                  selected: _topics.contains(topic.id),
                                  showCheckmark: false,
                                  onSelected: (bool selected) {
                                    setState(() {
                                      if (selected) {
                                        _topics.add(topic.id);
                                      } else {
                                        _topics.remove(topic.id);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          'Your home city',
                          style: context.typography.groupTitle,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Local stories and weather start here.',
                          style: context.typography.caption,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            for (final NewsLocation city in SlLocations.all)
                              ChoiceChip(
                                label: Text(city.label),
                                selected: locationId == city.id,
                                showCheckmark: false,
                                onSelected: (bool selected) {
                                  if (!selected) return;
                                  setState(() => _locationId = city.id);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Text(
                        _error!,
                        style: context.typography.caption.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      TextButton(
                        onPressed: _saving ? null : () => _finish(skip: true),
                        child: const Text('Skip for now'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                          ),
                        ),
                        onPressed: _saving ? null : () => _finish(skip: false),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Start reading'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finish({required bool skip}) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!skip) {
        final FollowingSnapshot snapshot = ref.read(
          followingControllerProvider,
        );
        final Map<String, FollowTarget> byId = <String, FollowTarget>{
          for (final FollowTarget target in snapshot.topics) target.id: target,
        };
        for (final String id in _topics) {
          final FollowTarget? target = byId[id];
          if (target == null || snapshot.isFollowed(id)) continue;
          await ref.read(followingControllerProvider.notifier).follow(target);
        }
        final String? locationId = _locationId;
        if (locationId != null) {
          await ref
              .read(settingsControllerProvider.notifier)
              .setActiveLocation(locationId);
        }
      }
      await ref.read(settingsControllerProvider.notifier).completeOnboarding();
      if (!mounted) return;
      context.go(AppRoutes.forYou);
    } catch (error) {
      // Partial writes are possible; do not mark onboarding complete or leave
      // the reader on a picker that silently did nothing.
      if (mounted) {
        setState(() {
          _error = 'We could not save your choices. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            context.colors.accentGradientEnd,
            context.colors.accentGradientStart,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'SLNews',
            style: context.typography.overline.copyWith(
              color: const Color(0xCCFFFFFF),
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Make the feed yours',
            style: context.typography.screenTitle.copyWith(
              color: Colors.white,
              fontSize: 30,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A couple of choices now, a much more relevant briefing every day.',
            style: context.typography.body.copyWith(
              color: const Color(0xE6FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}
