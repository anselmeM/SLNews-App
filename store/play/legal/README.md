# Legal pack — drafts and how to publish them

Drafts written against the shipped app, plus what to do with the pages the
`SLNews` backend already serves.

| File | Purpose |
| --- | --- |
| [PRIVACY-POLICY.md](PRIVACY-POLICY.md) | app-accurate privacy policy |
| [TERMS-OF-USE.md](TERMS-OF-USE.md) | app-accurate terms |
| [DELETE-ACCOUNT.md](DELETE-ACCOUNT.md) | public deletion page copy + the app/backend behaviour behind it |

These are drafts prepared from the code, not legal advice. Have a lawyer in Sierra
Leone review them before publishing — especially the liability, IP and governing-law
clauses.

## Placeholders to fill

| Placeholder | Where | Notes |
| --- | --- | --- |
| `{{EFFECTIVE DATE}}` | privacy, terms | the date they go live |
| `{{LEGAL ENTITY / OWNER NAME}}` | privacy §1, §12; terms §15 | person or company that will be the controller |
| `{{CONTACT EMAIL}}` | both documents, deletion page | must be monitored; `privacy@slnews.app` if the domain is yours |
| `{{DEMO ACCOUNT EMAIL}}` / `{{DEMO ACCOUNT PASSWORD}}` | DATA-SAFETY.md §5 | create a throwaway account for Play review |
| Domain | URLs throughout | drafts assume `https://slnews.app`; confirm it is the canonical site (`NEXT_PUBLIC_SITE_URL`) |

## Merge plan for the existing backend pages

The `SLNews` repo already serves `src/app/privacy/page.tsx` and
`src/app/terms/page.tsx`, both labelled "Effective for SLNews Web and Mobile Apps".
Two statements there describe **the website, not the app**:

1. **Meta (Facebook) Pixel** — an advertising pixel for web attribution. The Android
   app contains no pixel, no ad SDK and no advertising identifier.
2. **"Anonymous usage data (page views …)"** — the app has no analytics SDK.

Leaving them in a policy linked from Play would make the app's Data-safety answers
inconsistent with its own policy. Recommended fix (**option A**):

1. Update both pages so the web-only statements are explicitly web-only, e.g.
   *"On our website we use… The SLNews Android app does not include analytics,
   advertising or tracking SDKs."*
2. Add an **"Information the Android app handles"** section to the privacy page,
   using the table from `PRIVACY-POLICY.md` §3–5 (account data, synced reading state,
   push token when it ships, no location/permissions, service-provider list).
3. Add the financial-data disclaimer to the terms if it is not already there
   (`TERMS-OF-USE.md` §5).
4. Bump "Last updated" on both pages.
5. Add `src/app/delete-account/page.tsx` with the copy from `DELETE-ACCOUNT.md`, and
   link it from `/privacy`, `/terms` and the account section of the site.
6. Add `PRIVACY_URL` / `TERMS_URL` constants to the mobile app and surface both under
   Settings → About, plus a "Delete account" row when signed in (the in-app half of
   the Play deletion requirement).

**Option B**, if you would rather not touch the web copy: publish the app policy at
`https://slnews.app/privacy/mobile` and use that URL in Play. Cleaner separation, but
two policies to keep in sync.

Publishing also needs the account-deletion endpoint: Play requires the deletion path
to work, and the page above promises it. See launch doc item B3.

## Screens that should link these pages

- Settings → About: **Privacy policy**, **Terms of use**.
- Settings → SLNews account: **Delete account** (signed in only).
- The delete page: back-links to privacy and terms.
