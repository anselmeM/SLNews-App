# For You personalization

## Decision

For the current traffic stage SLNews uses an **explainable, on-device rule-based
ranker**, not a social-media-style ML feed. The full social feed architecture
(candidates → signals → ranking → re-ranking → feedback) is copied in principle;
the heavy ML and server-side profile are deliberately deferred until there is
enough traffic and interaction data.

## Phase 1 — shipped foundation

- `PersonalizationEngine` in `lib/core/domain/personalization.dart` is pure Dart
  and test-covered.
- Signals:
  - explicit follows (topics, publishers, city/topic tags)
  - reading history
  - saved stories
  - liked stories
  - topic and publisher affinity derived from the above
- Ranking keeps the editorial **Sierra Leone-first → international → sports**
  buckets, then ranks within each bucket.
- Hero diversification caps publishers and categories.
- A **From your follows** rail promotes explicit-follow stories and explains
  why they are there; those stories are removed from the rest of the stream.
- A **Settings → Personalize For You** toggle disables ranking and the follows
  rail. The device-local preference defaults to on.
- No personalization signal leaves the device.

Known Phase 1 limit: affinity is derived only from stories still present in the
current candidate pool. Phase 2 adds a persistent local interest profile so older
reads/saves continue to matter.

## Phase 2 — behavioural learning (next)

- Local event counters: opened, saved, liked, skipped, dwell time.
- Persist topic/publisher affinity over 7/30-day windows.
- “Show less like this” negative feedback.
- “Continue reading” rail.
- Personalization reset/diagnostics in Settings.
- No server profile; still on-device.

## Phase 3 — experimentation and scale

Only after enough monthly active readers and interaction data:

- privacy-safe, aggregated ranking experiments
- A/B framework and guardrail metrics
- on-device model or server-side ranker if justified
- collaborative/foundation signals only if content/data density supports them

## Guardrails

- Local-news floor and source/category diversity remain in every phase.
- Exploration slots prevent a filter bubble.
- Optimise for informed reading and retention, not clicks alone.
- Personalization must always be explainable and resettable.
- Saved stories, likes and follows may sync; reading history and ranking signals
  stay device-local.
