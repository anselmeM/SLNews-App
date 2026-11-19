# HTTPS App Links

Shared `https://` links are supposed to open the app. The code side is done; the
remaining step is a domain you control. This is the flip checklist.

## What is already in place

| Piece | Where | State |
|---|---|---|
| Custom scheme `slnews://article/<id>` | `AndroidManifest.xml` | declared, `autoVerify=false` |
| HTTPS filter `https://slnews.sl/article/<id>` | `AndroidManifest.xml` | declared, `autoVerify=true` |
| Host placeholder | `android/app/build.gradle.kts` (`deepLinkHost`) | `slnews.sl` |
| URI → route normalisation | `lib/core/routing/deep_link_uri.dart` | both shapes → `/article/:id` |
| Verification file | web `src/app/.well-known/assetlinks.json/route.ts` | serves the upload-key fingerprint |
| Tests | `test/core/deep_link_uri_test.dart`, `test/security/android_manifest_test.dart`, web route test | green |

Until the domain resolves and serves the file, Android simply leaves links in the
browser — a failed verification never breaks the app.

## Fingerprints

`assetlinks.json` must list **every** certificate that can sign an installed APK:

1. **Upload key** — signs CI and local release builds; already the default:
   `70:8D:7C:54:9C:10:F2:6A:39:E5:E7:59:DE:62:F6:C5:28:DF:92:B2:5F:AB:7B:2D:13:2A:B1:61:B0:44:A3:F2`
2. **Play app-signing key** — after Play App Signing is enrolled, copy the
   SHA-256 from Play Console → Setup → App signing and add it to the
   `ANDROID_APP_LINK_FINGERPRINTS` environment variable in Vercel, comma-separated:

   ```
   ANDROID_APP_LINK_FINGERPRINTS=70:8D:...,AB:CD:...
   ```

   The route normalises case/colons, deduplicates, and ignores malformed values.
   Redeploy after changing it; the cache header is 5 minutes.

## Flip checklist

1. **Point the domain at the web app.** Add `slnews.sl` (and `www`) in Vercel →
   Domains, then create the DNS records Vercel shows at the registrar. Confirm
   `https://slnews.sl/privacy` loads.
2. **Move Clerk to the production instance** on that domain (see
   [`PLAY-STORE-LAUNCH.md`](PLAY-STORE-LAUNCH.md) B10).
3. **Confirm the verification file:**
   ```bash
   curl -s https://slnews.sl/.well-known/assetlinks.json | jq .
   ```
   It must contain `com.slnews.mobile` and the upload-key fingerprint.
4. **Rebuild the app** (no code change needed; the host is already `slnews.sl`).
   Bump the version code; Play requires a new upload anyway.
5. **Verify on a device** with the production-signed build installed:
   ```bash
   adb shell pm get-app-links com.slnews.mobile
   adb shell pm verify-app-links --reverify com.slnews.mobile
   adb shell am start -a android.intent.action.VIEW \
     -d "https://slnews.sl/article/slnews-api:4821"
   ```
   `get-app-links` should report `verified` for `slnews.sl`; the last command must
   open the reader, not the browser.
6. **Test the real path:** share an article from the web app into WhatsApp and tap
   the link on a phone with the app installed.

## If verification fails

- `curl` the file over HTTPS and check the JSON is served as `application/json`.
- Compare the fingerprint byte-for-byte with
  `apksigner verify --print-certs <apk>`; a Play-installed build is signed by the
  Play key, not the upload key.
- `adb shell pm get-app-links com.slnews.mobile` reports `1024` style legacy
  states when the filter did not match; check `pathPrefix` and that the manifest
  was actually rebuilt.
- Verification is retried by Android periodically; `pm verify-app-links
  --reverify` forces it immediately.

## Changing the host

If the domain changes, update all four places in one commit: the Gradle
placeholder, `appLinkHosts` in `deep_link_uri.dart`, the manifest test
expectation, and the docs in this file.
