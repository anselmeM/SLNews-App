# Delete your SLNews account

Public page copy for `https://slnews.app/delete-account`, and the behaviour the app
and backend must implement to support it. Play requires **both** an in-app deletion
path and a web page that works without installing the app, because the app lets people
create accounts.

> Draft for owner review. Placeholders in `{{ }}` are listed in
> [README.md](README.md#placeholders-to-fill).

---

## Page copy

### Delete your SLNews account

You can delete your SLNews account and the data we hold about it at any time. Deleting
is free and does not require you to keep the app installed.

**In the app:** open SLNews → Settings (the ⋮ menu) → **SLNews account** → **Delete
account** → confirm. You will be signed out immediately.

**Without the app:** email **{{CONTACT EMAIL}}** from the address you signed up with
and ask us to delete your SLNews account. If you cannot email from that address, tell
us the address and we will verify another way before deleting.

**What gets deleted**

- your account record (email, display name, account identifier);
- the saved stories, likes and follows we synced for that account;
- any push-notification token we stored for the account.

**What is not affected**

- Content cached on your phone. Sign out and/or uninstall the app to clear it, or use
  "Clear cache" in the app's settings.
- Nothing is deleted from third-party sites you visited from SLNews.

**How long it takes**

Deletion is immediate for your account and synced data. Backups are purged on a
rolling basis within **90 days**. You will get a confirmation email when the deletion
is complete.

**Changed your mind?** Deletion cannot be undone; you can create a new account later,
but saved stories, likes and follows from the deleted account cannot be restored.

Questions: **{{CONTACT EMAIL}}** · [Privacy Policy](https://slnews.app/privacy) ·
[Terms of Use](https://slnews.app/terms)

---

## What the implementation must do

### In-app (Android)

1. **Entry point:** Settings → "SLNews account" → **Delete account**, visible only when
   signed in.
2. **Confirmation sheet:** explains what is deleted, requires typing or re-confirming,
   and states the action is irreversible. Offer "Delete" (destructive) and "Cancel".
3. **Call:** authenticated `DELETE /api/mobile/v1/account` with the Clerk session token.
4. **On success:** clear local user state (saved, likes, follows, preferences tied to
   the account), sign out of Clerk, return to For You with a confirmation snackbar.
5. **On failure:** keep the account, show the error and a retry path. Never leave the
   UI claiming deletion when the server refused.
6. **Accessibility:** the destructive action must be screen-reader labelled and not
   auto-focused.

### Backend (`SLNews` repo)

1. `DELETE /api/mobile/v1/account` — resolves the user from the Clerk session token
   (same helper as `/api/mobile/v1/sync`), then:
   - deletes `MobileBookmark`, `MobileReaction`, `MobileFollow`, `MobilePreference`,
     `MobileDevice` rows for the user (cascades already exist on the FKs);
   - deletes the `User` row;
   - calls Clerk's Backend API to delete the identity (`DELETE /v1/users/{id}`) so the
     sign-in cannot be reused;
   - returns `{ deleted: true }`, idempotent (second call also returns success).
2. `/delete-account` page — the copy above, with the contact address and links to
   `/privacy` and `/terms`.
3. Email requests: a documented manual runbook (verify sender, delete the same rows,
   log the request without retaining the address beyond the deletion record).

### Test cases

- signed-in deletion removes rows and the Clerk identity; the token stops working;
- a second delete call returns success without error;
- deletion while offline shows an error and leaves the account intact;
- the web page is reachable when signed out and from a browser with no app installed.
