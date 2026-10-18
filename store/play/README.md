# Play Store listing assets

Everything the Play Console asks for, generated from one script so a brand tweak is
a rerun rather than a dozen hand-edited PNGs.

```powershell
# 1. clean device captures (optional but preferred - see below)
$env:SLNEWS_STORE_CAPTURES='1'
flutter test test/store/screenshot_capture_test.dart
$env:SLNEWS_STORE_CAPTURES=''

# 2. compose every listing image + the Android launcher/splash assets
python tools/generate_store_assets.py
```

## What is here

| File | Play field | Size |
| --- | --- | --- |
| `icon-512.png` | App icon | 512×512, 32-bit PNG, no alpha |
| `feature-graphic-1024x500.png` | Feature graphic | 1024×500 |
| `screenshots/phone-01…07-*.png` | Phone screenshots | 1080×1920 |

Screenshots cover: For You, News, Sports, reader, Top stories section, search, Following.

## Regenerating the Android assets

The same script writes the launcher icon (legacy + adaptive foreground + monochrome
layer), the adaptive descriptor, its background colour and the splash wordmark into
`android/app/src/main/res`. Do not edit those PNGs/XML by hand; change the brand
constants at the top of `tools/generate_store_assets.py` and rerun.

## About the screenshot imagery

This toolchain has had no device or emulator attached, so captures come from the app
itself under `flutter test`: layout, type and copy are real, but remote images render
as the design-system placeholder (grey block with the outlet mark) because a widget
test has no network.

For the submitted listing, replace them with real captures:

1. Install the release build on a phone.
2. Capture the same seven screens (For You scrolled just past the offline banner,
   News, Sports, an article, Top stories, search results, Following).
3. Save them into `store/play/captures/` with the same names
   (`for_you.png`, `news.png`, `sports.png`, `article.png`, `section.png`,
   `search.png`, `following.png`).
4. Rerun step 2 above. The generator prefers `captures/` over the test renders.

## Play Console notes

- The icon must be 32-bit PNG with **no transparency** — the generated file is RGB.
- The feature graphic must not contain screenshots or device frames; this one is
  typographic on purpose.
- Screenshots must not show an offline banner or debug UI: the capture harness
  scrolls past the banner for that reason.
- Minimum 2 phone screenshots are required; we ship 7.
