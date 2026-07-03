#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPS_DIR="$HOME/Applications"
APP_DST="$APPS_DIR/Reclaim.app"
SUPPORT_DIR="$HOME/Library/Application Support/Reclaim"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LEGACY_PLIST="$LAUNCH_AGENTS/com.reclaim.scanner.plist"
LABEL="com.reclaim.scanner"

echo "==> Building Reclaim.app"
"$PROJECT_DIR/scripts/build-app.sh"

SRC_APP="$PROJECT_DIR/.build/Reclaim.app"
if [[ ! -d "$SRC_APP" ]]; then
  echo "ERROR: build did not produce $SRC_APP"
  exit 1
fi

echo "==> Installing to $APP_DST"
mkdir -p "$APPS_DIR" "$SUPPORT_DIR"
rm -rf "$APP_DST"
cp -R "$SRC_APP" "$APP_DST"

SCANNER_BIN="$APP_DST/Contents/MacOS/reclaim-scanner"

# The daily 09:00 scan schedule is now registered by the app itself via
# SMAppService (bundled LaunchAgent) on first launch — no launchctl needed.
# Remove any legacy hand-loaded agent from older installs to avoid a
# duplicate under the same label.
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  echo "==> Removing legacy LaunchAgent"
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
fi
rm -f "$LEGACY_PLIST"

cat <<EOF

Install complete.
  App:       $APP_DST
  Scanner:   $SCANNER_BIN
  Schedule:  daily at 09:00 (registered by app on first launch, $LABEL)
  Report:    $SUPPORT_DIR/report.json
  Whitelist: $SUPPORT_DIR/whitelist.json

FIRST LAUNCH (ad-hoc signed; Gatekeeper blocks 'open' until approved):
  1. Open Finder -> ~/Applications/
  2. Right-click Reclaim.app -> Open -> click Open in the dialog
  3. After that, 'open "$APP_DST"' works normally.

OR launch the binary directly (always works, bypasses Gatekeeper):
  "$APP_DST/Contents/MacOS/ReclaimApp" &

Run a scan now:      "$SCANNER_BIN"
Toggle login launch: menu bar -> "Launch at login"
EOF
