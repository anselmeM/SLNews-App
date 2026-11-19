# Tester guide

Thanks for testing SLNews. This build is a release build of the Android app; it
talks to the real news services, so treat it as the product.

## Get the build

`SLNews-1.0.0-68.apk` (Android 8.0+). Install it by opening the file on the phone
and allowing installs from your file manager/browser when prompted. It installs
alongside an older SLNews build only if the version code is higher (68 is).

## First run

1. Read the onboarding cards — you can change every choice later.
2. Allow notifications when asked. Breaking news and the topics you follow use
   notifications; without the prompt accepted you will not see them.
3. Optionally sign in: **Settings → SLNews account → Sign in**. Sign-in is on the
   test identity instance (capacity 100 readers), and it is what makes saved
   stories and follows follow you between devices. The app works signed out;
   alerts for followed topics work either way.

## What to exercise

- **For You** — scroll the mix; open a story; save it; like it; share it.
- **Following** — follow a topic, a team and a publisher; check the suggested
  list; open **Manage news topics** and **Manage sources**; in Sports, open a
  league and a team.
- **Sports** — the merged "European Leagues" section, a league page, a team page.
- **Search** — search a word from a headline you just saw.
- **Alerts** — wait for (or trigger) a breaking update and check the notification
  opens the right story.
- **Offline** — turn on airplane mode, reopen the app, confirm saved stories and
  the last feed still render.
- **Settings** — text size, theme, notification categories, account row.

## How to report

Send a message with:

- what you did, what you expected, what happened;
- a screenshot or screen recording;
- phone model, Android version, and whether you were on Wi-Fi or mobile data;
- the time it happened (so the crash/log trail can be matched).

Please do not post screenshots of the account screen with your email visible.

## Known limitations in this build

- Sign-in uses the **test** identity instance. Production sign-in is a separate
  switch that needs the domain; nothing you do here is lost when it moves.
- `https://slnews.sl/...` links still open the browser — App Links verification
  waits for that domain. `slnews://` links and in-app sharing work.
- Some deferred features are intentionally absent from v1: text-to-speech,
  translation, the home-screen widget, and full Krio/French localisation.
- Market quotes are indicative and may be delayed; they are not investment
  advice.

## Privacy

The build reports crashes to Sentry with no user identity, no IP address and no
screenshots attached. Reading state stays on the phone unless you sign in, in
which case it syncs to your account so it can follow you to another device.
