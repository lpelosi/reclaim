#!/usr/bin/env bash
set -euo pipefail
# End-to-end release: build (Developer ID, hardened) -> notarize -> staple app
# -> package DMG -> notarize+staple DMG -> publish GitHub Release.
#
#   Usage: scripts/release.sh [version]
#   e.g.:  scripts/release.sh 1.1.0
#
# Prereqs (one-time — see RELEASE.md):
#   - Apple Developer Program enrollment + "Developer ID Application" cert installed
#   - Notary credentials stored:  xcrun notarytool store-credentials reclaim-notary ...
#   - gh CLI installed + authenticated;  git remote 'origin' pointing at the repo
# Override the notary keychain profile name with $RECLAIM_NOTARY_PROFILE.

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

VERSION="${1:-$(tr -d '[:space:]' < "$PROJECT_DIR/VERSION")}"
NOTARY_PROFILE="${RECLAIM_NOTARY_PROFILE:-reclaim-notary}"
APP="$PROJECT_DIR/.build/Reclaim.app"
DIST="$PROJECT_DIR/dist"
DMG="$DIST/Reclaim-$VERSION.dmg"
TAG="v$VERSION"

echo "==> Releasing Reclaim $VERSION (tag $TAG)"

# Keep VERSION file in sync with the requested version.
echo "$VERSION" > "$PROJECT_DIR/VERSION"

# 1. Build, signed with Developer ID + hardened runtime (enforced).
RECLAIM_RELEASE=1 RECLAIM_VERSION="$VERSION" "$PROJECT_DIR/scripts/build-app.sh"

# 2. Notarize the app, then staple the ticket onto it (so it launches offline
#    on a fresh Mac with no Gatekeeper prompt).
echo "==> Notarizing app"
APP_ZIP="$(mktemp -d)/Reclaim.zip"
ditto -c -k --keepParent "$APP" "$APP_ZIP"
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"

# 3. Package the stapled app into a DMG.
"$PROJECT_DIR/scripts/make-dmg.sh" "$VERSION"

# 4. Notarize + staple the DMG itself.
echo "==> Notarizing DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# 5. Publish GitHub Release with the DMG attached.
echo "==> Publishing GitHub Release $TAG"
git tag -f "$TAG"
git push -f origin "$TAG"
gh release create "$TAG" "$DMG" \
  --title "Reclaim $VERSION" \
  --generate-notes

echo "Release $VERSION published."
echo "  DMG: $DMG"
