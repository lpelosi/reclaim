#!/usr/bin/env bash
set -euo pipefail
# Package the already-built (and ideally stapled) Reclaim.app into a
# distributable DMG with a drag-to-Applications layout.
#   Usage: scripts/make-dmg.sh [version]
# Version defaults to the VERSION file. Output: dist/Reclaim-<version>.dmg

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$PROJECT_DIR/.build/Reclaim.app"
VERSION="${1:-$(tr -d '[:space:]' < "$PROJECT_DIR/VERSION")}"
DIST="$PROJECT_DIR/dist"
DMG="$DIST/Reclaim-$VERSION.dmg"

[[ -d "$APP" ]] || { echo "ERROR: $APP not found. Run build-app.sh first."; exit 1; }

mkdir -p "$DIST"
rm -f "$DMG"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP" "$STAGING/Reclaim.app"
ln -s /Applications "$STAGING/Applications"   # drag-to-install target

echo "==> Building $DMG"
hdiutil create -volname "Reclaim $VERSION" \
  -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null

# Sign the DMG too if a Developer ID identity is available (nice-to-have; the
# stapled app inside is what actually satisfies Gatekeeper offline).
ID="${RECLAIM_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | \
  awk -F'"' '/Developer ID Application:/ {print $2; exit}')}"
if [[ -n "$ID" && "$ID" != "-" ]]; then
  # Developer ID signing timestamps via Apple's TSA, which flakes; retry.
  for attempt in 1 2 3 4 5; do
    if codesign --force --sign "$ID" "$DMG"; then break; fi
    echo "    DMG codesign attempt $attempt failed (TSA?); retrying in 5s…" >&2
    [[ $attempt -eq 5 ]] && { echo "ERROR: DMG codesign failed after retries" >&2; exit 1; }
    sleep 5
  done
fi

echo "Built $DMG"
