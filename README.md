# Reclaim

A lightweight macOS menu-bar app that finds reclaimable disk space — caches, logs, stale build artifacts, large files, and duplicates — and lets you review and trash them safely.

Everything is opt-in and reversible: Reclaim only ever moves items to the **Trash** (never a hard delete), never touches keepers, and sorts findings into risk tiers so you decide what goes.

## Install

1. Download the latest `Reclaim-x.y.z.dmg` from [**Releases**](https://github.com/lpelosi/reclaim/releases/latest).
2. Open the DMG and drag **Reclaim.app** to **Applications**.
3. Launch it. The app is signed and notarized by Apple, so it opens with no Gatekeeper warnings.

Reclaim lives in the menu bar (and opens a report window). On first launch it registers a daily background scan (9:00 AM).

### Grant Full Disk Access (recommended)

To scan protected folders (Desktop, Documents, Downloads, external drives) without a permission prompt for each one, grant Full Disk Access once:

- Menu bar → **Grant Full Disk Access…** → in System Settings, add **Reclaim.app** and toggle it on.

The grant persists across updates.

## How it works

Reclaim scans against a set of rules and groups everything into four tiers:

| Tier | Meaning |
|------|---------|
| 🟢 **Safe to delete** | Regenerable caches, logs, temp files. Low risk. |
| 🟡 **Review first** | Package-manager caches, build dirs, large/old/duplicate files. Check before deleting. |
| 🟠 **Heuristic** | Flagged by heuristics — worth a look. |
| 🔴 **Dangerous** | System-managed or root-owned (e.g. simulator runtimes). Shown for visibility; often need `sudo`/Xcode to remove. |

Tier sections are collapsible. Each item shows its size, path, category, and last-modified date. Select items and **Move to Trash**, or **Whitelist** paths you never want flagged again.

## Scan options

Open **Scan Options** in the report window to tune what a scan looks for (settings persist and apply to both manual and scheduled scans):

- **Large files** — flag big individual files (Review tier — often personal media you may want to keep).
- **Large folders** — flag large top-level folders under your chosen roots. Standard home folders (Documents, Desktop, Pictures, …) are always protected and never flagged as a whole.
- **Old files** — files not modified in over a year (and above a size floor).
- **Duplicate files** — content-hashed duplicate detection (on by default; the slowest step).
- **Include external drives** — extend scans into mounted `/Volumes`.
- **Scan folders** — pick which roots the large/old scans cover.
- **Minimum "large" size** — 100 MB / 500 MB / 1 GB.

A full scan takes ~30 seconds (rule resolution and sizing run in parallel).

## Safety

- Deletions go to the **Trash** — restore anything from there.
- **Keepers** (e.g. the original in a duplicate group) can never be selected for deletion.
- **Whitelist** any path or filename glob to permanently exclude it.
- Root-owned items are shown for visibility but can't be trashed by the app; Reclaim tells you when removal needs elevated privileges.

## Build from source

Requires macOS 13+ and the Swift toolchain (Xcode or Command Line Tools).

```sh
swift build                 # build both executables (debug)
scripts/build-app.sh        # release build → .build/Reclaim.app
scripts/install.sh          # build + install to ~/Applications (local dev)
```

The project is a Swift Package with three targets:
- `ReclaimCore` — shared model, scan rules, options, paths.
- `ReclaimScanner` — the `reclaim-scanner` CLI that performs scans and writes the report.
- `ReclaimApp` — the SwiftUI menu-bar app.

## Releasing

Maintainers: see [`RELEASE.md`](RELEASE.md). In short:

```sh
scripts/release.sh 1.2.0    # build → notarize → DMG → GitHub Release
```

## License

Personal project — no license granted yet.
