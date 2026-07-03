#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/Reclaim.app"
CONTENTS="$BUILD_DIR/Contents"

echo "==> swift build (release)"
cd "$PROJECT_DIR"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
APP_BIN="$BIN_DIR/ReclaimApp"
SCANNER_BIN="$BIN_DIR/reclaim-scanner"

if [[ ! -x "$APP_BIN" || ! -x "$SCANNER_BIN" ]]; then
  echo "ERROR: missing built binaries"
  exit 1
fi

if [[ ! -f "$PROJECT_DIR/Resources/AppIcon.icns" ]]; then
  echo "==> Generating AppIcon.icns"
  "$PROJECT_DIR/scripts/make-icon.sh"
fi

# Version: $RECLAIM_VERSION override, else VERSION file. Build number = $RECLAIM_BUILD or 1.
VERSION="${RECLAIM_VERSION:-$(tr -d '[:space:]' < "$PROJECT_DIR/VERSION")}"
BUILD_NUM="${RECLAIM_BUILD:-1}"

echo "==> Assembling Reclaim.app (version $VERSION build $BUILD_NUM)"
rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Library/LaunchAgents"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
cp "$APP_BIN" "$CONTENTS/MacOS/ReclaimApp"
cp "$SCANNER_BIN" "$CONTENTS/MacOS/reclaim-scanner"
chmod +x "$CONTENTS/MacOS/ReclaimApp" "$CONTENTS/MacOS/reclaim-scanner"

# Stamp version into the bundle Info.plist.
PB=/usr/libexec/PlistBuddy
"$PB" -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
"$PB" -c "Set :CFBundleVersion $BUILD_NUM" "$CONTENTS/Info.plist"

# Bundle the daily-scan LaunchAgent so the app can self-register it via
# SMAppService on other machines (recipients never run install.sh). The
# BundleProgram path is relative to the .app bundle root.
cat > "$CONTENTS/Library/LaunchAgents/com.reclaim.scanner.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.reclaim.scanner</string>
    <key>BundleProgram</key><string>Contents/MacOS/reclaim-scanner</string>
    <key>StartCalendarInterval</key>
    <dict><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
    <key>RunAtLoad</key><false/>
    <key>ProcessType</key><string>Background</string>
</dict>
</plist>
PLIST

# Pick a signing identity.
#  1. $RECLAIM_SIGN_IDENTITY  (explicit override)
#  2. "Developer ID Application: ..."  (proper distribution; passes Gatekeeper)
#  3. "Mac Developer: ..."             (dev cert; works on this Mac)
#  4. "Apple Development: ..."         (dev cert; works on this Mac)
#  5. "-"  (ad-hoc; Gatekeeper will reject 'open' on first launch)
SIGN_IDENTITY="${RECLAIM_SIGN_IDENTITY:-}"
for prefix in "Developer ID Application:" "Mac Developer:" "Apple Development:"; do
  if [[ -n "$SIGN_IDENTITY" ]]; then break; fi
  SIGN_IDENTITY="$(security find-identity -v -p codesigning | \
    awk -F'"' -v p="$prefix" '$0 ~ p {print $2; exit}')"
done
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

# Release builds MUST use a Developer ID cert (only kind that runs on other
# Macs after notarization). Set RECLAIM_RELEASE=1 to enforce.
if [[ "${RECLAIM_RELEASE:-0}" == "1" && "$SIGN_IDENTITY" != Developer\ ID\ Application:* ]]; then
  echo "ERROR: RECLAIM_RELEASE=1 requires a 'Developer ID Application' identity."
  echo "       Found: '${SIGN_IDENTITY:-none}'. Enroll in the Apple Developer Program"
  echo "       and install the Developer ID cert, or unset RECLAIM_RELEASE for a local build."
  exit 1
fi

echo "==> Codesigning with: $SIGN_IDENTITY"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  # Ad-hoc: sign inner binaries first, then the bundle (no --deep).
  codesign --force --sign - "$CONTENTS/MacOS/reclaim-scanner" >/dev/null 2>&1 || true
  codesign --force --sign - "$CONTENTS/MacOS/ReclaimApp" >/dev/null 2>&1 || true
  codesign --force --sign - "$BUILD_DIR" >/dev/null 2>&1 || true
  echo "    (ad-hoc — Gatekeeper will block 'open' until right-click -> Open once)"
else
  # Secure timestamp is required for notarization (Developer ID) but dev certs
  # (Mac Developer / Apple Development) can't reach the TSA — skip it for local
  # dev builds so signing doesn't fail.
  TS=()
  if [[ "$SIGN_IDENTITY" == Developer\ ID\ Application:* ]]; then
    TS=(--timestamp)
  fi
  # Sign inner executables (hardened runtime) inside-out, then the outer
  # bundle. --deep is deprecated and rejected by notarization.
  for bin in reclaim-scanner ReclaimApp; do
    codesign --force --options runtime ${TS[@]+"${TS[@]}"} \
      --sign "$SIGN_IDENTITY" "$CONTENTS/MacOS/$bin"
  done
  codesign --force --options runtime ${TS[@]+"${TS[@]}"} \
    --sign "$SIGN_IDENTITY" "$BUILD_DIR"
  echo "==> Verifying signature"
  codesign --verify --strict --verbose=2 "$BUILD_DIR"
fi

echo "Built $BUILD_DIR"
codesign -dv "$BUILD_DIR" 2>&1 | grep -E "Identifier|Authority|TeamIdentifier" || true
