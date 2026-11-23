# Phone screenshots — recapture required

The PNGs that used to live here were **headless renders with fixture content**:
placeholder photography and a Following list that marked every catalogue entry as
followed. They were deleted rather than shipped, because a reviewer comparing the
image with the app would see a mismatch.

Final art must come from a real phone running the build under review:

1. Follow **3–4 teams, a league, 2–3 topics and a publisher**; let images load.
2. Connect the phone and run:
   ```powershell
   powershell -NoProfile -File scripts/capture_store_screenshots.ps1
   ```
3. The script captures the seven screens into `store/play/captures/` and runs
   `tools/generate_store_assets.py`, which recreates `phone-*.png` here.

Full details and the per-screen checklist:
[`docs/STORE-SCREENSHOTS.md`](../../../docs/STORE-SCREENSHOTS.md).

Until that has been done, the listing has **no uploadable screenshots** — this
directory is intentionally empty. Do not substitute the headless harness output:
it is useful for layout review only.
