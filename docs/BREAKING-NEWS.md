# Breaking-news policy

The app no longer trusts a feed flag or the demo seed to decide what is
"breaking". `lib/core/domain/breaking_news_policy.dart` scores every incoming
story and only promotes it when the score and an impact/urgency signal agree.

## Signals

| Signal | Effect |
|---|---|
| Fresh report (≤ 2h) | +2 |
| Recent report (≤ 6h) | +1 |
| Older than 24h | −3 |
| Hard-news category (politics, world, health, business, mining) | +1 |
| Wire source | +1 |
| Explicit headline urgency ("breaking", "just in", "developing", "urgent") | +2 |
| Impact terms (deaths, explosion, fire, flood, earthquake, coup, state of emergency, outbreak, etc.) | +2 to +4 each, capped at +6 |
| Opinion / analysis / review / how-to headline | −2 |
| Editor/feed `isBreaking` flag | +1 only; cannot qualify on its own |

Promotion requires a score of at least **5** and one of:

- at least one impact term worth **3+**, or
- an urgency term in a hard-news category.

## Applied to

- RSS parsing (`rss_feed_source.dart`)
- Aggregator API rows (`sl_news_api_source.dart`)
- Loose JSON/REST sources (`json_article_mapper.dart`)
- Bundled seed (`seed_loader.dart`)
- Cached articles on startup, so an upgrade cannot resurrect an old banner
  (`offline_first_article_repository.dart`)

## Tuning

- Add/remove impact phrases in `_impactTerms`.
- Adjust the threshold in `BreakingNewsPolicy.threshold`.
- Keep the policy pure and add a `breaking_news_policy_test.dart` case for every
  new editorial rule.
