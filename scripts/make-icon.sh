#!/usr/bin/env bash
set -euo pipefail

# Generates Resources/AppIcon.icns from an SF Symbol via a small Swift script.
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_ICNS="$PROJECT_DIR/Resources/AppIcon.icns"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SRC_PNG="$TMP_DIR/icon_1024.png"
ICONSET="$TMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

cat > "$TMP_DIR/render.swift" <<'SWIFT'
import AppKit

let size = NSSize(width: 1024, height: 1024)
let img = NSImage(size: size)
img.lockFocus()

// Background — rounded square, deep blue-teal gradient.
let rect = NSRect(origin: .zero, size: size)
let path = NSBezierPath(roundedRect: rect, xRadius: 224, yRadius: 224)
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.12, green: 0.36, blue: 0.55, alpha: 1),
    NSColor(srgbRed: 0.05, green: 0.18, blue: 0.32, alpha: 1)
])!
gradient.draw(in: path, angle: -90)

// Foreground glyph: externaldrive.badge.minus
let cfg = NSImage.SymbolConfiguration(pointSize: 580, weight: .semibold)
if let sym = NSImage(systemSymbolName: "externaldrive.badge.minus",
                     accessibilityDescription: nil)?
    .withSymbolConfiguration(cfg) {
    sym.isTemplate = true
    NSColor.white.set()
    let s = sym.size
    let aspect = s.width / s.height
    let drawH: CGFloat = 600
    let drawW: CGFloat = drawH * aspect
    let drawRect = NSRect(
        x: (size.width - drawW) / 2,
        y: (size.height - drawH) / 2,
        width: drawW,
        height: drawH
    )
    sym.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
}

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("failed to encode PNG\n".utf8))
    exit(1)
}
let outPath = CommandLine.arguments[1]
try png.write(to: URL(fileURLWithPath: outPath))
SWIFT

echo "==> Rendering 1024px PNG"
swift "$TMP_DIR/render.swift" "$SRC_PNG"

echo "==> Generating iconset sizes"
for sz in 16 32 64 128 256 512; do
  sips -z $sz $sz "$SRC_PNG" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
  sips -z $((sz*2)) $((sz*2)) "$SRC_PNG" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
cp "$SRC_PNG" "$ICONSET/icon_512x512@2x.png"

echo "==> Building .icns"
iconutil -c icns "$ICONSET" -o "$OUT_ICNS"
echo "Wrote $OUT_ICNS"
