# Phase 3 — experiments, metrics and scale

Status: **3B-A (dormant upload)**. This build computes an anonymous, sticky
experiment assignment, collects consent-gated aggregate counters locally, and
ships the remote-config/outbox seams. It does **not** upload any analytics and
the ranker experiment is disabled.

The reader-facing control is Settings → News → **Anonymous diagnostics**,
default **off**. With it off no aggregate counters are recorded. With it on,
only category-level local counters are written; article ids are used solely in
memory to avoid double-counting impressions and are never persisted.

The product rule stays: personalization is local-first, explainable and
account-scoped. Phase 3 must not turn reading behaviour into a server-side user
profile.

## 1. Privacy boundary

### Never collected or uploaded

- account id, email, session token or Clerk subject
- article ids, reading positions, reading history, search text or follows
- precise location, IP-derived location, device advertising id
- raw event logs or free-text fields
- an experiment assignment linked to an account

### Allowed for aggregate metrics (when Phase 3B is enabled)

A row may contain only:

| Dimension | Example | Why it is bounded |
|---|---|---|
| UTC day | `2026-11-25` | no session timing or timezone |
| experiment key + variant | `for_you_ranker_v1 / treatment` | no per-user assignment |
| category | `politics` | coarse content class, not article id |
| audience bucket | `sierraLeone` | existing feed ordering bucket |
| metric | `open`, `save`, … | enum with fixed meaning |
| count | `≥ 50` | suppresses small cohorts |

There is no row for a single reader or a single story. Every uploaded row must
clear **k = 50** events; rows below that stay local. Local aggregate counters
are pruned after **30 days**.

### Experiment seed

The experiment seed is a random 32-hex install-local value generated once and
stored at `experiments.installSeed.v1`. It is not derived from the account,
advertising id or location. It exists only to make bucket assignment sticky
across launches.

## 2. Experiment design

Phase 3A adds:

- `ExperimentAssigner` — deterministic FNV-1a/32 bucketing into 1000 buckets
- `ExperimentAssignment` — experiment key, variant, bucket, enabled
- `forYouRankingAssignmentProvider` — sticky assignment, **disabled by default**
- `RankingExperimentConfig` — the seam for a future validated remote config

Initial experiment:

| Field | Value |
|---|---|
| Key | `for_you_ranker_v1` |
| Control | current tuned on-device ranker |
| Treatment | Phase 3B candidate ranker |
| Split | 90 / 10 |
| Enabled | **false** until the gates below are met |

The assignment is computed even while disabled so the plumbing can be tested,
but the ranking path does not consume the treatment flag yet. No remote config
is fetched in 3A.

## 3. Metrics

### Primary outcome

**Qualified story opens per feed session** — an open counts once per story per
session, only after the reader reaches the article page. This avoids rewarding
headline clicks that bounce immediately.

### Supporting metrics

- save rate per qualified open
- like rate per qualified open
- 7-day and 30-day return rate (cohort-level only)
- completion rate from local dwell/progress classification
- Continue reading rail taps
- dismissals per feed impression

### Guardrails

| Guardrail | Maximum acceptable change |
|---|---|
| Sierra Leone audience share in For You | no more than **1.0 percentage point** below control |
| Unique publishers in the first 12 stories | no more than **1** below control |
| Category concentration (top category share) | no more than **3 pp** above control |
| Dismiss/skip rate | no more than **2 pp** above control |
| Feed render/load latency p95 | no more than **50 ms** above control |
| Crash-free sessions | no lower than control |

A treatment that improves opens but breaches a guardrail does not ship. The
decision unit is the experiment cohort, never an individual reader.

## 3B-A implementation (this change)

- **Consent:** `analyticsEnabled` defaults to false, is device-local, and
  clearing it removes the local aggregate document and session impression set.
- **Local metrics:** impressions, opens, saves, likes, dismissals and Continue
  reading taps feed `aggregateMetricsProvider`. Counters are day/category/
  audience/variant only, pruned to 30 days and suppressed below k = 50 on
  publishable reads.
- **Remote config:** `RemoteRankingExperimentConfig` strictly parses
  `{key, enabled, treatmentPercent, killSwitch}`; malformed payloads, errors
  and timeouts return no config. A remote kill switch always disables the
  experiment. There is no endpoint or fetch in 3B-A.
- **Upload outbox:** `AggregateUploadOutbox` deduplicates k-anonymous batches,
  caps the queue, retries with backoff and deletes successful batches. No
  production code calls it and `aggregateUploadEnabled` is false.
- **Data Safety:** unchanged, because nothing is transmitted.
- **Ranking:** unchanged; the experiment remains disabled.

## 4. Gates before enabling upload (3B)

All must hold:

- at least **10,000 monthly active installs**
- at least **50,000 qualified opens per month**
- aggregate buckets routinely reach k = 50 without merging categories
- backend endpoint supports signed, idempotent aggregate batches
- Data Safety declaration and privacy policy updated for aggregate diagnostics
- a visible analytics control (off means no upload, local aggregation stops too)
- documented retention and deletion process for aggregate rows
- dashboards for primary metrics + every guardrail
- kill switch that disables assignment and upload without an app release

## 5. Gates before a server-side ranker (3C)

All must hold:

- at least **8 weeks** of clean Phase 3B data
- treatment shows a statistically credible primary-metric lift
- every guardrail remains within bounds for the full window
- no regression for new or anonymous readers
- offline feed still works with the local fallback ranker
- latency and battery budgets are measured on low-end Android devices
- a documented rollback to the local ranker

Until then, ranking stays entirely on-device and deterministic.

## 6. Rollout sequence

1. **3A (this change)** — privacy boundary, assignment/bucketing, aggregate
   metric model, guardrail + threshold documentation. No upload, no UI change.
2. **3B** — remote experiment config, opt-in aggregate upload, dashboards,
   analytics control and disclosure. Experiment stays at 10% and local ranking
   remains the control.
3. **3C** — evaluate a candidate ranker against the gates above; only then
   consider server-side learning.

## 7. Non-goals

- building a per-user server profile
- cross-device or cross-account personalization
- selling or sharing reading behaviour
- article-level analytics
- using push tokens or sponsorship install ids for experiment linkage beyond
  the anonymous seed
- launching a model before the sample-size and guardrail gates are met
