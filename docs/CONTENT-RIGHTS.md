# Content rights: decision memo

Status: **decision required** · Prepared 2026-11-19 · Owner: product/legal
Related: [PLAY-STORE-LAUNCH.md](PLAY-STORE-LAUNCH.md) B4, [CONTENT-OUTREACH.md](CONTENT-OUTREACH.md)

## 1. What we actually publish (audit)

| Source class | Examples | What we store | Where it is shown |
|---|---|---|---|
| Full-text publishers (scraped) | The Sierra Leone Telegraph, Politico SL, Concord Times | `Article.paragraphs` — every `<p>` over 40 chars extracted from the publisher's page; title, image URL, author, date | App reader renders the paragraphs as the story body; web article page |
| RSS outlets | Sierraloaded, BBC Africa, BBC Sport, BBC Sport Africa | Title, feed summary, image URL, link | Feed cards, reader (summary/body if feed carries it) |
| REST/JSON publishers | Awoko, Standard Times, Kallon, Reuters, AP | Title, summary, image, link — **only if the endpoint returns data**; several are unverified placeholders | Feed cards, reader |
| Sports wire | ESPN (client-side API), Yahoo Sports (RSS) | Headline, summary, score data, image, link | Sports surfaces |
| Video | YouTube channel feeds | Video id, title, thumbnail, channel | Video reel |

Three facts drive the risk:

1. **Full-text reproduction without documented permission.** The ingestion pipeline fetches the publisher's HTML page and stores its paragraphs; the reader shows them in full, not as a teaser. This is the highest-exposure behaviour.
2. **Images are hotlinked, not licensed.** We store the publisher's image URL (with a cache-busting fingerprint) and the app requests it directly. That is both a rights question and a bandwidth/terms question for the publisher.
3. **No robots.txt check, and a browser-like User-Agent.** The crawler sends Chrome's
   User-Agent string (overridable with `SCRAPER_USER_AGENT`) and never consults
   `robots.txt` before fetching article pages or sitemaps. Checked on 2026-11-19, all
   three publishers' robots files allow article paths (only `/wp-admin` or Joomla
   internals are disallowed), so honouring robots would **not** reduce ingestion today —
   but the check is a compliance requirement, and a bot identity with a contact URL is
   the honest default.

What we do **not** do: bypass paywalls, republish user-generated content, strip bylines, or rehost images on our own storage.

## 1a. Adopted posture (2026-11-23)

The app now implements **Option A: excerpt + link-out** for every external
outlet. Until a signed licence or written permission is recorded:

- Ingestion keeps only the feed summary; full body markup is discarded for RSS
  and JSON sources.
- Publisher-hosted images and publisher logos are not requested or displayed.
  Cards fall back to the publisher mark; the reader has no hero image.
- The reader shows a **Preview** card with the short excerpt, attribution and a
  single **Read full story** hand-off to the publisher.
- Bundled seed content remains full because it is owned/demo content.
- The feed cache key was versioned so a pre-policy full-text cache is never
  rendered after upgrade.
- `FeedSourceConfig.allowsFullText` / `allowsRemoteImages` are the only switches
  that can enable full text or remote art; `test/data/outlet_rights_test.dart`
  fails if a production outlet is accidentally marked licensed.

Still required before public launch: legal review of the excerpt length, a
recorded permission/licence register per outlet, robots.txt/User-Agent policy in
the scraper, and refreshed store copy that does not imply full in-app articles.

## 2. Legal frame (not legal advice)

- **Sierra Leone**: the Copyright Act 2011 protects original literary and artistic works. Fair dealing covers reporting current events and criticism/review, but it is a defence applied case-by-case — it is not a licence to reproduce whole articles or to build an archive.
- **Attribution** matters independently: moral rights include the right to be identified, and our byline/source link is a mitigation, not a substitute for permission.
- **Territoriality**: the app is distributed globally through Play. A publisher's rights are territorial, but a US or EU rightsholder can still send takedowns; Play's IP policy responds to them.
- **Wire copy** (Reuters/AP) is licensed to the publisher, not to us; even headlines can carry restrictions depending on the feed terms.

This is why the launch gate treats content rights as an owner decision, not an engineering one: the acceptable posture is a business choice about relationships, traffic and risk appetite.

## 3. Options

### A. Link-out only (lowest risk, fastest)
Headline + ≤ 2-sentence excerpt + byline + link to the publisher. No stored body, no publisher images (or only a neutral placeholder).

- **Risk**: low. Closest to what search engines and social cards do; still not risk-free (headline/excerpt copying).
- **Cost**: ~2 days engineering: per-source `contentMode`, excerpt trim at ingestion, reader "Read the full story at …" CTA, image fallback.
- **Product impact**: the reader loses in-app long-form reading — a significant UX change for a news app.
- **When to choose**: if launch is inside 4 weeks and no permissions exist yet.

### B. Permission-first, full text (highest value, slowest)
Signed permission from each publisher before their body is shown; keep full-text reading for partners.

- **Risk**: low once signed; high until every live source is covered.
- **Cost**: outreach time (days–weeks per publisher), plus a per-source licence register and revocation path (~1 week engineering).
- **Product impact**: best reader experience; also opens revenue-share and content-supply conversations.
- **When to choose**: if there is a relationship owner who can commit the outreach time.

### C. Hybrid — link-out by default, full text for partners (recommended)
Every source starts in link-out mode; a signed publisher is switched to `licensed` and gets full text + images. A per-source switch, not a rebuild.

- **Risk**: low-to-medium, decreasing as partners sign.
- **Cost**: A + ~3 days for the licence register/switch and removal flow.
- **Product impact**: launch-able immediately; improves source by source.
- **When to choose**: this is the defensible default; it also gives outreach a concrete offer ("we already link to you; permission unlocks full text and imagery").

### D. Own and public-domain content only
Drop aggregation; publish own reporting, government releases, and clearly licensed feeds.

- **Risk**: lowest.
- **Cost**: highest — it changes the product into a publisher, not an aggregator.
- **When to choose**: only if the rights position cannot be resolved and launch must proceed.

## 4. Recommendation

**Take C.** Ship link-out-first, start outreach now with the template in [CONTENT-OUTREACH.md](CONTENT-OUTREACH.md), and treat `licensed` as an upgrade per publisher. This matches the product's actual differentiator (a fast, offline-first Sierra Leonean reader) without betting the launch on unsigned full-text reproduction.

Per-source disposition at launch:

| Source | Launch mode | Reason |
|---|---|---|
| The Sierra Leone Telegraph | link-out until signed | full text currently scraped |
| Politico SL | link-out until signed | full text currently scraped |
| Concord Times | link-out until signed | full text currently scraped |
| Sierraloaded | link-out | RSS summary only |
| BBC Africa / BBC Sport / BBC Sport Africa | link-out | BBC feed terms; do not cache bodies |
| Awoko, Standard Times, Kallon | link-out | unverified endpoints; low content volume |
| Reuters / AP | link-out | wire copy licensed to publishers, not us |
| ESPN / Yahoo Sports | link-out | headline/score data; check API terms |
| YouTube video feeds | as-is | YouTube ToS covers embedding; thumbnail use |

## 5. Engineering work after the decision

1. **`contentMode` per source** (`link` | `excerpt` | `full`), enforced at ingestion *and* at render, with `excerpt` truncation (≤ 280 chars, sentence boundary).
2. **Licence register** — a table or config recording publisher, contact, signed date, scope (text/images/archive), revocation date. The switch reads it; no code deploy to change a source.
3. **Robots.txt compliance** — fetch and cache `robots.txt` per host, honour
   `Disallow`, and replace the browser-like User-Agent with a descriptive bot
   identity carrying a contact URL. This is a defect fix, independent of the
   decision; the 2026-11-19 check shows it will not cut off the current three
   publishers.
4. **Image policy** — for `link` sources, use a neutral placeholder or publisher logo instead of the article image; for licensed sources, keep hotlinking only if the licence allows it.
5. **Removal workflow** — a public page and an inbox alias; unpublish within 48 h, record the request, and prevent re-ingestion by URL. The scraper needs a suppression list keyed by canonical URL and publisher id.
6. **Attribution standard** — byline, outlet name, "Read the full story" link, and a visible content-policy link wherever excerpts appear.

## 6. Open questions for counsel

1. Does the Copyright Act 2011 fair-dealing provision cover headline + 2-sentence excerpt with attribution for a commercial app?
2. Is hotlinking a publisher image an infringement or a terms-of-service issue in this jurisdiction?
3. What notice and takedown wording should the public content-policy page carry?
4. Do we need a separate position for UK/US publishers (BBC, Reuters, AP, ESPN) whose feeds we consume directly?

## 7. Decision record

- [ ] Option chosen: A / B / C / D
- [ ] Outreach owner and weekly time commitment
- [ ] Launch position for the three full-text publishers
- [ ] Date permission work starts / deadline for first signed publisher
- [ ] Who signs off the public content-policy copy
