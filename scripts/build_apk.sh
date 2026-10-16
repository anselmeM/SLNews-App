#!/usr/bin/env bash
# Builds a release APK for SLNews on Linux/macOS (or CI).
#
#   ./scripts/build_apk.sh              # fat APK
#   ./scripts/build_apk.sh --split      # one APK per ABI
#   SKIP_TESTS=1 ./scripts/build_apk.sh # skip analyze + test
#
# Requires the Flutter SDK on PATH (or FLUTTER_ROOT set) and a JDK 17.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

FLUTTER="${FLUTTER:-}"
if [[ -z "$FLUTTER" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    FLUTTER="$(command -v flutter)"
  elif [[ -n "${FLUTTER_ROOT:-}" && -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
    FLUTTER="${FLUTTER_ROOT}/bin/flutter"
  else
    echo "Flutter SDK not found. Add flutter to PATH or set FLUTTER_ROOT." >&2
    exit 1
  fi
fi

split_args=()
if [[ "${1:-}" == "--split" ]]; then
  split_args+=(--split-per-abi)
fi

echo "SLNews release build"
echo "  project : $project_root"
echo "  flutter : $FLUTTER"

if [[ ! -f android/key.properties ]]; then
  echo "warning: android/key.properties missing - signing with the debug key." >&2
fi

"$FLUTTER" pub get

if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  "$FLUTTER" analyze
  "$FLUTTER" test test/core test/data test/features
fi

"$FLUTTER" build apk --release "${split_args[@]}"

out_dir="build/dist"
mkdir -p "$out_dir"
shopt -s nullglob
for apk in build/app/outputs/flutter-apk/*.apk; do
  [[ "$apk" == *unsigned* ]] && continue
  target="$out_dir/$(basename "$apk")"
  cp -f "$apk" "$target"
  size="$(du -h "$target" | cut -f1)"
  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(sha256sum "$target" | cut -d' ' -f1)"
  else
    hash="$(shasum -a 256 "$target" | cut -d' ' -f1)"
  fi
  echo
  echo "APK: $target"
  echo "  size   : $size"
  echo "  sha256 : $hash"
done

echo
echo "Install on a connected device with:"
echo "  $FLUTTER install --release"
