# Security audit — 2026-11-14

**Scope**

| Surface | Target |
|---|---|
| Web | `https://sl-news.vercel.app` (`SLNews-Web`) |
| API | `https://slnewsapiscapper.onrender.com` (`SLNewsAPIScapper`) |
| Mobile | `SLNews-App` (Flutter, release code 53/54 line) |
| Repos | all three, current `master` |

**Method:** static review of auth/authorization, input handling, secrets,
dependencies, headers and mobile configuration; dependency audits; live
header and unauthenticated-response probes against the deployed services;
regression tests for every fix.

---

## 1. Result

**No critical or high-severity vulnerability remains open.** Two fixable
security issues were found and fixed during the audit (one rate-limit bypass,
one body-limit gap). Dependency audits are clean across web and scraper; the
app secret scan passes.

| Area | Result |
|---|---|
| Web dependency audit | **0 vulnerabilities** (prod + dev) |
| Scraper dependency audit | **0 vulnerabilities** (prod + dev) |
| App secret scan | **pass** (456 tracked files) |
| Web security headers | HSTS, CSP, nosniff, frame protection, permissions, referrer policy present |
| Scraper headers | Helmet CSP, HSTS, no-referrer, COOP/CORP, CORS allow-list |
| Admin auth | server-side cookie gate + page guard + constant-time key compare + rate-limited login |
| Cron endpoints | bearer-only, 401 without secret |
| Mobile APIs | authenticated, per-user scoping, DB rate limits |
| Unauthenticated probes | `/api/stats`, `/api/news`, `/api/cron/sync`, `/api/mobile/v1/sync` → **401**; `/admin/*` → **307** to login |

---

## 2. Findings and remediation

### S-01 — Scraper rate-limit bypass via rotating Authorization header (Medium) — FIXED

The global API limiter keyed its bucket on the SHA-256 of any `Authorization`
header. Because the limiter runs **before** authentication, a caller could send
a different invented bearer value on every request and receive a fresh
`RATE_LIMIT_MAX` budget each time, defeating per-client throttling of the
expensive auth paths and all data routes.

**Fix:** `rateLimitKey()` now keys on the normalised client IP only
(PR #39)
(`ipKeyGenerator`), with a comment documenting why pre-auth credentials must
never select a bucket. Added a regression test that sends three requests from
one IP with three different invented tokens and asserts the third is `429`.

### S-02 — CSP report endpoint buffered an unbounded body (Low/Medium) — FIXED

`POST /api/csp-report` called `request.text()` and sliced afterwards, so the
`8 KiB` limit was applied only after the whole body had been buffered. A large
or chunked body could consume memory on every request.

**Fix:** a stream reader enforces `MAX_BODY_BYTES` while reading (and rejects a
oversized `Content-Length` immediately), returns `413` and cancels the stream.
Added a regression test for a 9 KB report. (PR #148)

### S-03 — CSP missing `object-src` / `base-uri` (Low) — FIXED

Added `object-src 'none'` and `base-uri 'self'` to the site-wide policy
(PR #149; live header re-checked after deployment).
`default-src` already covered most legacy plugin paths; this removes the
remaining injection surface around `<object>`/`<base>`.

### S-04 — Six dev advisories in scraper (Low) — FIXED

`vitest`/`@vitest/coverage-v8` were on 4.1.11 (below the patched 4.1.12) and
`swagger-jsdoc` pulled vulnerable `glob`/`minimatch`. Upgraded Vitest and added
a `glob ^14.0.3` override; `npm audit` is now 0 including dev.

### S-05 — App WebView runs publisher JS unrestricted (Low, accepted)

The "Read original" page intentionally needs JavaScript for the publisher page,
reading-progress channel and typography injection. There is no JavaScript bridge
that exposes app data; the progress channel only parses a clamped float.
Navigation is policy-checked (`ArticleWebMode`): `javascript:` is blocked,
same-publisher HTTP(S) stays in-page, every other scheme/host opens externally.
`canReadOriginal()` accepts only absolute HTTP(S) URLs. Residual risk is the
publisher's own page behaviour, equivalent to reading it in a browser.

### S-06 — CSP keeps `script-src 'unsafe-inline'` (Low, accepted)

Next.js/Clerk bootstrap scripts are inline. The app has no user-controlled HTML
sink (article markup is parsed/sanitized locally, not injected through
`dangerouslySetInnerHTML` except static JSON-LD). Moving to nonces is the
documented next step if a live ad publisher is added; the CSP report endpoint
already collects violations.

### S-07 — SSRF guard does not resolve DNS (Low, accepted)

`assertSafeFetchUrl()` rejects non-HTTP(S), credentials, localhost/.local/
.internal names and private literal IPs, but does not perform async DNS
resolution, so a DNS-rebinding hostname could theoretically resolve to a
private address. The fetches are limited to public feed/article/image URLs and
the worker runs outside the private network; adding an allow-list/DNS pin is a
future hardening item.

### S-08 — Public web HTML advertises `Access-Control-Allow-Origin: *` (Info)

Observed on the marketing/HTML surface. It exposes only public, already-public
page content; authenticated APIs are same-origin or explicitly allow-listed and
set `Cache-Control: no-store`. No credential-bearing response is wildcarded.

### S-09 — Client IP source trust (Info)

Web rate limiting reads the first `X-Forwarded-For` entry; Vercel is the
trusted proxy and normalises this. The scraper already uses a numeric
`trust proxy` hop count. Revisit if the deployment proxy changes.

---

## 3. Live probe evidence

```text
GET https://sl-news.vercel.app/                200
  Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
  Content-Security-Policy: default-src 'self'; ... object-src 'none';
                            base-uri 'self'; frame-ancestors 'self'
  X-Content-Type-Options: nosniff
  X-Frame-Options: SAMEORIGIN
  Referrer-Policy: strict-origin-when-cross-origin
  CSP tail: worker-src 'self' blob:; object-src 'none';
            base-uri 'self'; frame-ancestors 'self' (live verified)

GET https://slnewsapiscapper.onrender.com/api/health   200
  content-security-policy, strict-transport-security,
  cross-origin-opener-policy, cross-origin-resource-policy,
  referrer-policy: no-referrer

Origin: https://evil.example -> /api/news
  401; access-control-allow-origin remains https://sl-news.vercel.app
  (evil origin is not reflected)

/api/stats -> 401
/api/news -> 401
/api/cron/sync -> 401
/admin/sponsorships -> 307 (login)
/api/mobile/v1/sync -> 401
```

---

## 4. Recommendations (residual)

1. Move the web CSP to nonce-based `script-src` before enabling a live ad
   publisher; keep the CSP report endpoint as the detector.
2. Add DNS-resolution/allow-list pinning to the scraper outbound guard.
3. Rotate the embedded app API key as part of release operations; the app
   already prefers Clerk session tokens when identity is configured.
4. Keep the scraper on `npm audit` 0 by cadence; the same `glob`/Vitest overrides
   are now in place.
5. Play launch security remains: reviewer demo account, privacy mailbox, data
   deletion path (already implemented and rate-limited).
