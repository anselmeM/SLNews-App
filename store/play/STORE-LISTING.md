# Play Store listing copy

Ready to paste into Play Console. Character limits are noted; the drafts stay inside
them. Placeholders in `{{ }}` mirror [legal/README.md](legal/README.md#placeholders-to-fill).

## App name (max 30)

`SLNews — Sierra Leone news` (27)

Alternates: `SLNews: Sierra Leone News` (27) · `SLNews` (6, too thin for search)

## Short description (max 80)

`Sierra Leone's daily news, sports, markets and video in one clean feed.` (73)

Alternates:
- `Local headlines, live scores, markets and video — built for Sierra Leone.` (75)
- `Sierra Leone news, without the noise: headlines, sports, markets, video.` (72)

## Full description (max 4000)

```
SLNews brings Sierra Leone's newsrooms into one calm, fast feed.

Headlines from Awoko, SLBC, Politico, Concord Times, Sierra Telegraph and other
Sierra Leonean and international outlets, collected in one place and linked back to
the original reporting — so you always read the full story at the source.

BUILT FOR THE WAY PEOPLE READ HERE
• A clean feed that opens instantly and works on slow connections
• Offline reading: the last edition stays on your phone when the network drops
• Four tabs: For you, News, Sports, Following
• Dark mode, adjustable text size, and motion that respects your settings

TOP STORIES AND SECTIONS
• A swipeable lead carousel for the day's biggest stories
• Browse by section: Top stories, Politics, Business, Cars and Vehicles, Music,
  Culture, Sports, Health, Tech, Education, Mining, World
• Trending now, picks for you and your next read

SPORTS
• Live scores and fixtures, with the latest results at a glance
• Follow your teams, leagues and locations to shape your feed
• Sierra Leone Premier League and international competitions

MARKETS AND STOCKS
• Index board with intraday trend lines for Nasdaq, Russell 2000, Dow Jones,
  S&P 500 and TSX
• Filter by index, trending, most active and top gain
• Attributable market data, informational only — not investment advice

VIDEO
• Video moments: swipe through clips from local and international outlets
• Watch in the app, with pause, mute, full screen and like

READER
• Section label, byline and publication time, exactly as the source reports it
• Floating bar with follow, text size, like, translate and share
• Keyword tags, related stories and back-to-top
• Reading progress, so you know how far you have left

FIND ANYTHING
• Search every story and video, with recent searches kept on your device

YOURS
• Save stories and like posts; follow teams, topics and locations
• Sign in (optional) to sync saved stories, likes and follows across devices
• Choose your location to get local headlines and weather
• Notification preferences for breaking news, editor's picks and sports

ABOUT CONTENT
SLNews is an aggregator: headlines and summaries come from third-party publishers and
remain their property. Each story links to the original source. We do not claim to be
the publisher of that reporting, and publisher names and marks are used only to
identify the source. If you are a rights holder, contact us at privacy@slnews.sl.

We do not sell your data. The app has no advertising or analytics tracking SDKs.

Questions or feedback: privacy@slnews.sl
Privacy: https://sl-news.vercel.app/privacy
Terms: https://sl-news.vercel.app/terms
```

Character count: ~2,450 — well under 4,000.

## What's new (max 500) — first release

```
First release of SLNews.

• One feed for Sierra Leone's headlines, with offline reading
• Sports scores and fixtures, plus markets and video moments
• Search, save, like and follow what matters to you
• Dark mode, adjustable text size and reduce-motion support

Tell us what to improve: privacy@slnews.sl
```

## Listing metadata

| Field | Value |
| --- | --- |
| Category | News & Magazines |
| Tags | news, Sierra Leone, Africa, sports, business |
| Contact email | `contact@slnews.sl` |
| Website | https://sl-news.vercel.app |
| Privacy policy | https://sl-news.vercel.app/privacy |
| Account deletion | https://sl-news.vercel.app/delete-account |
| Ads | Yes — sponsored cards, labelled "Ad" |
| Content rating | Teen / 13+ (news with real-world violence references) |
| Countries | Start with Sierra Leone; expand after a stable week |

## Graphics (already generated)

| Asset | File |
| --- | --- |
| Icon 512×512 | `store/play/icon-512.png` |
| Feature graphic 1024×500 | `store/play/feature-graphic-1024x500.png` |
| Phone screenshots ×7 | `store/play/screenshots/phone-*.png` |
| Landscape promo (web/social) | `store/play/promo-panels-1350x800.png` |

Screenshot order and captions:

1. **Your day in one feed** — For You carousel and stream
2. **Browse by section** — News pills and section grid
3. **Scores and fixtures** — Sports scoreboard and stories
4. **Read without the clutter** — article reader and action bar
5. **Top stories, all of them** — pushed section with photo header
6. **Search every story** — results grouped into stories and videos
7. **Follow what matters** — Following with teams, locations and topics

## Copy rules for this listing

- **Do not** write "official", "the news app of Sierra Leone", or anything implying we
  publish the aggregated reporting. That is the fastest route to an IP/misrepresentation
  complaint, and the rights situation for scraped RSS is unresolved (launch doc B4).
- **Notifications may be described as available** (push shipped in code 52+): breaking
  news alerts on the topics and teams the reader follows. Keep it to what the app does —
  do not promise alert types that are not implemented (e.g. per-market or comment
  alerts).
- **Do not** promise exact figures, "fastest", or offline behaviour beyond what is
  tested (feeds and the last edition are cached; a story never loaded before is not).
- Keep the financial disclaimer line — Play's financial-content reviewers look for it
  when market data is displayed.
- Re-run `python tools/generate_store_assets.py` after replacing `captures/` with
  real-device screenshots, so the listing art keeps the same treatment.
