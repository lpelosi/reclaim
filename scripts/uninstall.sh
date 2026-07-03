#!/usr/bin/env bash
set -euo pipefail

LABEL="com.reclaim.scanner"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS/com.reclaim.scanner.plist"
APP="$HOME/Applications/Reclaim.app"
SUPPORT_DIR="$HOME/Library/Application Support/Reclaim"

echo "==> Unloading LaunchAgent"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

echo "==> Removing plist"
rm -f "$PLIST"

echo "==> Removing app bundle"
rm -rf "$APP"

read -r -p "Remove $SUPPORT_DIR (report, whitelist, log)? [y/N] " ans
case "$ans" in
  [yY]*) rm -rf "$SUPPORT_DIR"; echo "Removed $SUPPORT_DIR" ;;
  *) echo "Kept $SUPPORT_DIR" ;;
esac

echo "Uninstall complete."
