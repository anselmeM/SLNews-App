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
- Reading history, dwell/progress and the derived affinity profile are scoped
  per local account and never leave the device. Saved stories, likes and follows
  are account state and may sync; ranking uses the saved/liked sets present on
  the device, so synced items can influence ranking. Reading history and the
  affinity profile itself are not synchronized.

Known Phase 1 limit: affinity is derived only from stories still present in the
current candidate pool. Phase 2 adds a persistent local interest profile so older
reads/saves continue to matter.

## Phase 2 — behavioural learning (shipped)

- Local event log: opened, read (dwell + progress), saved, liked, skipped and
  explicit dismissals.
- Topic/publisher affinity over a 30-day window, with full weight inside 7 days
  and half weight up to 30 days.
- Short, shallow reads become negative skip signals.
- **Show less like this** hides the story immediately and lowers its
  topic/publisher affinity.
- **Continue reading** rail resolves unfinished reading positions and shows
  progress.
- **Settings → Personalization data** shows local signal counts and can reset
  the profile.
- Sync-applied saves/likes never train the profile; only reader actions do.
- Reading history and the engagement profile are isolated per account, so a
  shared device cannot carry one reader's interests into another's For You.
- Explicit team and league follows tag sports stories and rank them ahead of
  recency-only sports stories.
- Followed publisher and city candidates are included even when they are absent
  from the general top/story feed.
- Shared tags contribute topic affinity, duplicate story occurrences are counted
  once, and the follows rail keeps local coverage ahead of international
  coverage.
- Exploration reserves in-bucket feed slots for a less-personalized story; it is
  not just a small score bonus.
- No server profile; all ranking is still on-device.

Known Phase 2 limit: it remains a transparent weighted model, not a learned
ranking model. Phase 3 defines experimentation and privacy-safe scaling.

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
- Saved stories, likes and follows may sync and can influence ranking on the
  device; reading history, dwell/progress and the affinity profile stay
  device-local.
