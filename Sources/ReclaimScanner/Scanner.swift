import Foundation
import ReclaimCore

public final class Scanner {
    let whitelist: Whitelist
    let reporter: ProgressReporter
    let options: ScanOptions
    let fm = FileManager.default

    public init(whitelist: Whitelist,
                reporter: ProgressReporter = ProgressReporter(),
                options: ScanOptions = ScanOptions()) {
        self.whitelist = whitelist
        self.reporter = reporter
        self.options = options
    }

    public func run() -> Report {
        let totalRules = Rules.all.count
        reporter.update(phase: "rules", current: 0, total: totalRules,
                        label: "Resolving scan rules…", force: true)

        var items: [ReportItem] = []
        for (idx, rule) in Rules.all.enumerated() {
            reporter.update(phase: "rules", current: idx, total: totalRules,
                            label: "Rule: \(rule.description)")
            let paths = resolve(rule.resolve)
            for path in paths {
                guard !whitelist.contains(path) else { continue }
                guard fm.fileExists(atPath: path) else { continue }
                items.append(ReportItem(
                    path: path,
                    size: 0,
                    tier: rule.tier,
                    category: rule.category,
                    description: rule.description,
                    lastModified: nil,
                    ruleId: rule.id
                ))
            }
        }
        reporter.update(phase: "rules", current: totalRules, total: totalRules,
                        label: "Rules complete", force: true)

        // Opt-in Review-tier scans, driven by ScanOptions.
        if options.scanLargeFiles {
            reporter.update(phase: "largeFiles", current: 0, total: 1,
                            label: "Scanning for large files…", force: true)
            items.append(contentsOf: largeFileItems())
        }
        if options.scanLargeDirs {
            reporter.update(phase: "largeDirs", current: 0, total: 1,
                            label: "Scanning for large folders…", force: true)
            items.append(contentsOf: largeDirItems())
        }
        if options.flagOldFiles {
            reporter.update(phase: "oldFiles", current: 0, total: 1,
                            label: "Scanning for old files…", force: true)
            items.append(contentsOf: oldFileItems())
        }

        let deduped = dedupe(items)

        reporter.update(phase: "sizing", current: 0, total: deduped.count,
                        label: "Computing sizes…", force: true)
        var sized: [ReportItem] = []
        for (idx, item) in deduped.enumerated() {
            reporter.update(phase: "sizing", current: idx, total: deduped.count,
                            label: (item.path as NSString).lastPathComponent)
            var i = item
            // Items pre-sized during their scan (e.g. large folders) keep it.
            if i.size == 0 { i.size = sizeOf(path: item.path) }
            if i.size > 0 {
                if i.lastModified == nil { i.lastModified = mtimeOf(path: item.path) }
                sized.append(i)
            }
        }
        reporter.update(phase: "sizing", current: deduped.count, total: deduped.count,
                        label: "Sizing complete", force: true)

        if options.scanDuplicates {
            reporter.update(phase: "duplicates", current: 0, total: 1,
                            label: "Scanning for duplicate files…", force: true)
            let dupRoots = options.includeExternalDrives
                ? DuplicateFinder.defaultRoots + externalVolumes()
                : DuplicateFinder.defaultRoots
            let dupItems = DuplicateFinder(roots: dupRoots, whitelist: whitelist).find()
            sized.append(contentsOf: dupItems)
            reporter.update(phase: "duplicates", current: 1, total: 1,
                            label: "Duplicate scan complete", force: true)
        }

        return Report(generated: Date(), items: sized.sorted { $0.size > $1.size })
    }

    // MARK: - Opt-in scans

    /// Roots the large/old scans walk: the user's chosen tilde roots, plus
    /// mounted external volumes when enabled.
    private func effectiveRoots() -> [String] {
        var roots = options.roots.map(Paths.expand)
        if options.includeExternalDrives { roots += externalVolumes() }
        // Drop roots that don't exist so `find` doesn't error.
        return roots.filter { fm.fileExists(atPath: $0) }
    }

    /// Mounted volumes under /Volumes, excluding the boot volume symlink.
    private func externalVolumes() -> [String] {
        let vols = (try? fm.contentsOfDirectory(atPath: "/Volumes")) ?? []
        return vols.map { "/Volumes/\($0)" }.filter {
            (try? fm.destinationOfSymbolicLink(atPath: $0)) == nil  // skip the "/" symlink
        }
    }

    /// Large individual files (Review — often personal media the user keeps).
    private func largeFileItems() -> [ReportItem] {
        let mb = max(1, Int(options.minLargeBytes / 1_000_000))
        var out: [ReportItem] = []
        for root in effectiveRoots() {
            let cmd = "find \(shellQuote(root)) \(Self.prunePredicate) -o -type f -size +\(mb)M -print 2>/dev/null | grep -v '/Applications/'"
            for path in shellPaths(cmd) where !whitelist.contains(path) {
                out.append(ReportItem(
                    path: path, size: 0, tier: .review, category: "Large File",
                    description: "Large file — possibly personal, review",
                    ruleId: "large.file"))
            }
        }
        return out
    }

    /// Large folders (Review): direct child dirs of each root, sized once.
    private func largeDirItems() -> [ReportItem] {
        var out: [ReportItem] = []
        for root in effectiveRoots() {
            let children = (try? fm.contentsOfDirectory(atPath: root)) ?? []
            for name in children where !Self.pruneDirNames.contains(name) && !name.hasPrefix(".") {
                let path = (root as NSString).appendingPathComponent(name)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue,
                      !whitelist.contains(path) else { continue }
                let size = sizeOf(path: path)
                guard size >= options.minLargeBytes else { continue }
                out.append(ReportItem(
                    path: path, size: size, tier: .review, category: "Large Folder",
                    description: "Large folder — review before deleting",
                    lastModified: mtimeOf(path: path), ruleId: "large.dir"))
            }
        }
        return out
    }

    /// Old, sizeable files not modified within `oldFileDays` (Review).
    private func oldFileItems() -> [ReportItem] {
        let floor = min(options.minLargeBytes, ScanOptions.oldFileMinBytes)
        let mb = max(1, Int(floor / 1_000_000))
        var out: [ReportItem] = []
        for root in effectiveRoots() {
            let cmd = "find \(shellQuote(root)) \(Self.prunePredicate) -o -type f -mtime +\(options.oldFileDays) -size +\(mb)M -print 2>/dev/null | grep -v '/Applications/'"
            for path in shellPaths(cmd) where !whitelist.contains(path) {
                out.append(ReportItem(
                    path: path, size: 0, tier: .review, category: "Old File",
                    description: "Not modified in over a year — review",
                    ruleId: "old.file"))
            }
        }
        return out
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Drop exact duplicate paths (first rule wins) AND drop any path whose
    /// ancestor is already kept (avoids double-counting parent + child).
    private func dedupe(_ items: [ReportItem]) -> [ReportItem] {
        let ordered = items.sorted { $0.path.count < $1.path.count }
        var kept: [ReportItem] = []
        var keptPaths: [String] = []
        for item in ordered {
            if keptPaths.contains(item.path) { continue }
            if keptPaths.contains(where: { item.path.hasPrefix($0 + "/") }) { continue }
            kept.append(item)
            keptPaths.append(item.path)
        }
        return kept
    }

    /// Dirs to prune from full-home `find` walks: system Library, iCloud Drive
    /// (stalls waiting on cloud downloads), and dep/build dirs we never delete
    /// from here. Skipping them avoids the traversal stalls that hung scans.
    private static let prunePredicate =
        "\\( -path '*/Library/*' -o -path '*/Mobile Documents/*' -o -path '*/.Trash/*' "
        + "-o -name node_modules -o -name .git \\) -prune"

    /// Top-level folder names skipped by the large-folder scan (system/managed).
    private static let pruneDirNames: Set<String> = [
        "Library", "Applications", ".Trash", "node_modules", ".git"
    ]

    private func resolve(_ res: Resolution) -> [String] {
        switch res {
        case .literal(let p):
            return [Paths.expand(p)]
        case .glob(let pattern):
            return shellPaths("ls -d \(Paths.expand(pattern)) 2>/dev/null")
        case .shell(let cmd):
            return shellPaths(cmd)
        case .stale(let base, let name, let staleDays):
            let cmd = "find \(Paths.expand(base)) \(Self.prunePredicate) -o -type d -name '\(name)' -prune -print 2>/dev/null"
            return shellPaths(cmd).filter { parentStale($0, days: staleDays) }
        case .largeFiles(let base, let minBytes):
            let mb = max(1, Int(minBytes / 1_000_000))
            let cmd = "find \(Paths.expand(base)) \(Self.prunePredicate) -o -type f -size +\(mb)M -print 2>/dev/null | grep -v '/Applications/'"
            return shellPaths(cmd)
        }
    }

    private func parentStale(_ path: String, days: Int) -> Bool {
        let parent = (path as NSString).deletingLastPathComponent
        guard let attrs = try? fm.attributesOfItem(atPath: parent),
              let mtime = attrs[.modificationDate] as? Date else { return false }
        return Date().timeIntervalSince(mtime) > Double(days) * 86400
    }

    private func sizeOf(path: String) -> Int64 {
        // Use `du -sk` for accuracy across dirs/files.
        let out = runProcess("/usr/bin/du", ["-sk", path], timeout: 60)
        let kb = out.split(separator: "\t").first.flatMap { Int64($0.trimmingCharacters(in: .whitespaces)) } ?? 0
        return kb * 1024
    }

    private func mtimeOf(path: String) -> Date? {
        (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    private func shellPaths(_ cmd: String) -> [String] {
        let out = runShell(cmd)
        return out.split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func runShell(_ cmd: String) -> String {
        // Shell rules can trigger full-home `find` walks; cap them so one stuck
        // traversal (e.g. cloud-synced dir waiting on downloads) can't hang the
        // whole scan indefinitely.
        return runProcess("/bin/zsh", ["-c", cmd], timeout: 120)
    }

    /// Run a subprocess and return its stdout, killing it if `timeout` seconds
    /// elapse. Prevents a single stuck `find`/`du` from parking the scanner
    /// forever in `waitUntilExit()`. Returns whatever stdout was produced.
    private func runProcess(_ launchPath: String, _ args: [String], timeout: TimeInterval) -> String {
        let proc = Process()
        proc.launchPath = launchPath
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run() } catch { return "" }

        let deadline = DispatchWorkItem { [weak proc] in
            guard let proc, proc.isRunning else { return }
            proc.terminate()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)

        // Read stdout to EOF (also unblocks a full pipe buffer), then wait.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        deadline.cancel()

        if proc.terminationStatus == SIGTERM || proc.terminationReason == .uncaughtSignal {
            reporter.update(phase: "timeout", current: 0, total: 1,
                            label: "Timed out: \(launchPath) \(args.last ?? "")", force: true)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
