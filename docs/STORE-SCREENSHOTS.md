# Store screenshots

The Play listing images are composed from device captures in
`store/play/captures/` by `tools/generate_store_assets.py`. This is the
procedure for taking those captures on a real phone.

## Why real captures

`test/store/screenshot_capture_test.dart` can render the screens headlessly, and
that is useful for layout checks, but it substitutes fixture photography from
`test/store/images/` because widget tests cannot make network requests. Those
renders are **illustrative, not final**: store art should show the app with real
publisher images and a real reader state.

## Before you start

1. Install the build under review (`SLNews-1.0.0-<code>.apk`) on a phone.
2. Complete onboarding, then **follow 3–4 teams, a league, 2–3 topics and a
   publisher** so Following and Sports look lived-in.
3. Sign in if you want the account row to show a real name; otherwise the
   "Not signed in" state is fine.
4. Settings: light theme, default text size, notifications on.
5. Connect the phone with USB debugging and accept the RSA prompt. Confirm:
   `adb devices` lists exactly one device.
6. Let the feed load fully; avoid the offline banner and any spinner.

## Capture

```powershell
powershell -NoProfile -File scripts/capture_store_screenshots.ps1
```

The script prompts for each screen, captures it to `store/play/captures/`, and
then runs the generator. Navigate to the named screen and press Enter:

| File | Screen |
|---|---|
| `for_you.png` | For You, scrolled just past the offline banner |
| `news.png` | News tab, first category |
| `sports.png` | Sports tab, scoreboard and standings visible |
| `following.png` | Following tab, top of the subscriptions |
| `article.png` | Any article reader, with the hero image loaded |
| `section.png` | Top stories section |
| `search.png` | Search for `leone` with results shown |

Review the regenerated `store/play/screenshots/phone-*.png`. If one is weak,
re-run with `-Only <name>` after fixing the screen state.

## Rules

- No status-bar clutter: enable demo mode if the carrier name is ugly
  (`adb shell settings put global sysui_demo_allowed 1` then a demo-mode
  broadcast), or crop is not allowed — Play accepts the status bar.
- Do not show personal data: no real email, no notification with a private
  message.
- Keep the same language and theme across all seven images.
- The first screenshot is the most important; it should be For You with a real
  lead story and no empty card.

## Fallback

If no phone is available, the generated renders are acceptable for internal
review only. Do not submit them to Play with fixture photography; the mismatch
between headlines and images is visible to reviewers and users.
