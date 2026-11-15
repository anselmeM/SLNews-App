# Dependency automation

The app uses GitHub Dependabot for scheduled dependency PRs and a validation gate
before auto-merging safe updates.

## What runs automatically

| Ecosystem | Schedule | Grouping | Auto-merge |
|---|---|---|---|
| `pub` (Flutter/Dart) | Mondays 06:00 Africa/Freetown | Patch + minor in one grouped PR | Yes, after the dependency check and APK build pass |
| `gradle` (`/android`) | Mondays 06:30 | Patch + minor grouped | No — manual review |
| `github-actions` | Mondays 07:00 | Patch + minor grouped | No — manual review |

Major `pub` updates are always separate PRs and are never auto-merged. The same
applies to every Gradle and GitHub Actions update, because those can change the
release build itself.

Dependabot **security updates** are enabled in repository settings; they arrive
as normal Dependabot PRs and follow the same patch/minor auto-merge rule. A
security update that requires a major version jump stays open for manual review.

## Auto-merge gate

`dependabot-auto-merge.yml` runs from `pull_request_target` with a write token,
but deliberately does not check out or execute PR code. For a Dependabot **pub**
patch/minor PR it waits for both:

1. `Verify pub dependency update` — the secret-free `Dependency check` workflow
   (`flutter pub get`, format check, analyze, full test suite, coverage ratchet).
2. `Analyze, test and package the release APK` — compile/package validation.

Once both are green it squash-merges and deletes the branch. A failure or a
45-minute timeout leaves the PR open.

Dependabot PR workflows do not receive repository secrets, so the signed AAB job
is skipped for Dependabot PRs. The AAB gate still runs on the `master` push
created by the merge. This is why the AAB workflow has a `dependabot[bot]` guard.

## Manual refresh

When you want the same refresh immediately:

```powershell
flutter pub upgrade          # newest versions allowed by pubspec.yaml
flutter pub outdated         # check remaining majors
flutter analyze
flutter test --concurrency=1
```

To accept a new direct minor/patch, update its constraint in `pubspec.yaml`;
Dependabot will keep it fresh after that. Do not run
`flutter pub upgrade --major-versions` without reviewing the migration notes:
the app intentionally holds `xml < 7` because of the
`clerk_flutter -> flutter_svg -> vector_graphics_compiler` constraint, and
`flutter_local_notifications`, `cupertino_icons` and other majors need their own
review.

## Failure handling

- **Dependency check fails** — fix or reply on the PR; the auto-merge job exits.
- **APK build fails** — same; do not merge until the Dart tests/analyze and APK
  build both pass.
- **AAB fails after merge** — the master push is red; fix forward or revert the
  merge commit. Dependabot will retry the update if it is still needed.
- **Major update** — review the changelog, run the app on a device, then merge
  manually.
